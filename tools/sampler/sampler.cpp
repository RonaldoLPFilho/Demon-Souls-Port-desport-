// SPDX-License-Identifier: GPL-2.0-only
// desport: amostrador de CPU por thread, sem administrador (PLAN.md Fase 4, item 0).
//
// A cada intervalo, pausa cada thread do processo, lê a pilha (até MaxFrames quadros com
// StackWalk64), retoma, e no fim simboliza com DbgHelp (PDB do kyty_emulator) e grava JSON:
//   { "pid", "seconds", "hz", "threads": [ { "tid", "name", "cpu_ms", "samples",
//       "stacks": [ { "count", "frames": [ { "addr", "module", "symbol" } ] } ] } ] }
// Endereços fora de módulos carregados (código do jogo mapeado pelo emulador) ficam sem
// símbolo; tools/sample_report.py os traduz para eboot+offset com o mapa do log.txt.
//
// Uso: sampler.exe --pid N | --name kyty_emulator.exe  [--seconds 20] [--hz 200] --out arq.json

#include <windows.h>
#include <dbghelp.h>
#include <tlhelp32.h>

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr int MaxFrames = 12;

struct ThreadData {
	HANDLE                                handle = nullptr;
	std::string                           name;
	uint64_t                              cpu_start_100ns = 0;
	uint64_t                              samples = 0;
	std::map<std::vector<uint64_t>, uint64_t> stacks;
};

uint64_t ThreadCpu100ns(HANDLE h) {
	FILETIME c, e, k, u;
	if (!GetThreadTimes(h, &c, &e, &k, &u)) return 0;
	auto v = [](FILETIME f) { return (static_cast<uint64_t>(f.dwHighDateTime) << 32) | f.dwLowDateTime; };
	return v(k) + v(u);
}

std::string ThreadName(HANDLE h) {
	PWSTR w = nullptr;
	std::string out;
	if (SUCCEEDED(GetThreadDescription(h, &w)) && w != nullptr) {
		int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
		if (n > 1) {
			out.resize(n - 1);
			WideCharToMultiByte(CP_UTF8, 0, w, -1, out.data(), n, nullptr, nullptr);
		}
		LocalFree(w);
	}
	return out;
}

DWORD FindPid(const char* name) {
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	PROCESSENTRY32 pe {sizeof(pe)};
	DWORD pid = 0;
	for (BOOL ok = Process32First(snap, &pe); ok; ok = Process32Next(snap, &pe)) {
		if (_stricmp(pe.szExeFile, name) == 0) pid = pe.th32ProcessID;
	}
	CloseHandle(snap);
	return pid;
}

void RefreshThreads(DWORD pid, std::map<DWORD, ThreadData>& threads) {
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
	THREADENTRY32 te {sizeof(te)};
	for (BOOL ok = Thread32First(snap, &te); ok; ok = Thread32Next(snap, &te)) {
		if (te.th32OwnerProcessID != pid || threads.count(te.th32ThreadID)) continue;
		HANDLE h = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION,
		                      FALSE, te.th32ThreadID);
		if (h == nullptr) continue;
		auto& t           = threads[te.th32ThreadID];
		t.handle          = h;
		t.cpu_start_100ns = ThreadCpu100ns(h);
	}
	CloseHandle(snap);
}

std::vector<uint64_t> Sample(HANDLE process, HANDLE thread) {
	std::vector<uint64_t> frames;
	if (SuspendThread(thread) == static_cast<DWORD>(-1)) return frames;
	CONTEXT ctx {};
	ctx.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
	if (GetThreadContext(thread, &ctx)) {
		STACKFRAME64 sf {};
		sf.AddrPC.Offset    = ctx.Rip;
		sf.AddrPC.Mode      = AddrModeFlat;
		sf.AddrFrame.Offset = ctx.Rbp;
		sf.AddrFrame.Mode   = AddrModeFlat;
		sf.AddrStack.Offset = ctx.Rsp;
		sf.AddrStack.Mode   = AddrModeFlat;
		frames.push_back(ctx.Rip);
		while (static_cast<int>(frames.size()) < MaxFrames &&
		       StackWalk64(IMAGE_FILE_MACHINE_AMD64, process, thread, &sf, &ctx, nullptr,
		                   SymFunctionTableAccess64, SymGetModuleBase64, nullptr)) {
			if (sf.AddrPC.Offset == 0) break;
			if (frames.size() > 1 || sf.AddrPC.Offset != frames[0]) frames.push_back(sf.AddrPC.Offset);
		}
	}
	ResumeThread(thread);
	return frames;
}

void JsonString(FILE* f, const std::string& s) {
	fputc('"', f);
	for (unsigned char c: s) {
		if (c == '"' || c == '\\') fprintf(f, "\\%c", c);
		else if (c < 0x20) fprintf(f, "\\u%04x", c);
		else fputc(c, f);
	}
	fputc('"', f);
}

} // namespace

int main(int argc, char** argv) {
	DWORD       pid     = 0;
	const char* name    = nullptr;
	const char* out     = nullptr;
	double      seconds = 20.0;
	int         hz      = 200;
	for (int i = 1; i + 1 < argc; i += 2) {
		if (!strcmp(argv[i], "--pid")) pid = strtoul(argv[i + 1], nullptr, 10);
		else if (!strcmp(argv[i], "--name")) name = argv[i + 1];
		else if (!strcmp(argv[i], "--seconds")) seconds = atof(argv[i + 1]);
		else if (!strcmp(argv[i], "--hz")) hz = atoi(argv[i + 1]);
		else if (!strcmp(argv[i], "--out")) out = argv[i + 1];
	}
	// Modo de experimento: muda a prioridade de threads ao vivo (SetThreadPriority, -2..2 ou 15
	// para TIME_CRITICAL) e sai. Ex.: --set-priority 2 --tids 1234,5678
	for (int i = 1; i + 1 < argc; i += 2) {
		if (strcmp(argv[i], "--set-priority") != 0) continue;
		const int   priority = atoi(argv[i + 1]);
		const char* tids     = nullptr;
		for (int k = 1; k + 1 < argc; k += 2) {
			if (!strcmp(argv[k], "--tids")) tids = argv[k + 1];
		}
		if (tids == nullptr) {
			fprintf(stderr, "sampler: --set-priority precisa de --tids\n");
			return 2;
		}
		int failures = 0;
		for (const char* p = tids; *p != '\0';) {
			char*       end = nullptr;
			const DWORD tid = strtoul(p, &end, 10);
			HANDLE      h   = OpenThread(THREAD_SET_LIMITED_INFORMATION | THREAD_QUERY_LIMITED_INFORMATION, FALSE, tid);
			const bool  ok  = h != nullptr && SetThreadPriority(h, priority);
			printf("tid %lu: %s (prioridade agora %d)\n", tid, ok ? "ok" : "FALHOU",
			       h != nullptr ? GetThreadPriority(h) : 0);
			failures += ok ? 0 : 1;
			if (h != nullptr) CloseHandle(h);
			p = (*end == ',') ? end + 1 : end;
			if (end == p && *p != ',') break;
		}
		return failures == 0 ? 0 : 1;
	}
	if (pid == 0 && name != nullptr) pid = FindPid(name);
	if (pid == 0 || out == nullptr || hz <= 0) {
		fprintf(stderr, "uso: sampler --pid N | --name exe [--seconds S] [--hz H] --out arq.json\n");
		return 2;
	}
	HANDLE process = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
	if (process == nullptr) {
		fprintf(stderr, "sampler: OpenProcess(%lu) falhou: %lu\n", pid, GetLastError());
		return 1;
	}
	SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);
	SymInitialize(process, nullptr, TRUE);

	std::map<DWORD, ThreadData> threads;
	const auto period = std::chrono::microseconds(1000000 / hz);
	const auto start  = std::chrono::steady_clock::now();
	auto       next_refresh = start;
	timeBeginPeriod(1);
	while (std::chrono::steady_clock::now() - start < std::chrono::duration<double>(seconds)) {
		auto tick = std::chrono::steady_clock::now();
		if (tick >= next_refresh) {
			RefreshThreads(pid, threads);
			next_refresh = tick + std::chrono::seconds(1);
		}
		for (auto& [tid, t]: threads) {
			auto frames = Sample(process, t.handle);
			if (frames.empty()) continue;
			t.samples++;
			t.stacks[frames]++;
		}
		std::this_thread::sleep_until(tick + period);
	}
	timeEndPeriod(1);
	const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();

	FILE* f = fopen(out, "wb");
	if (f == nullptr) {
		fprintf(stderr, "sampler: não abriu %s\n", out);
		return 1;
	}
	std::map<uint64_t, std::pair<std::string, std::string>> symbols; // addr -> (módulo, símbolo)
	auto resolve = [&](uint64_t addr) -> const std::pair<std::string, std::string>& {
		auto it = symbols.find(addr);
		if (it != symbols.end()) return it->second;
		std::pair<std::string, std::string> r;
		IMAGEHLP_MODULE64 mod {sizeof(mod)};
		if (SymGetModuleInfo64(process, addr, &mod)) r.first = mod.ModuleName;
		alignas(SYMBOL_INFO) char buf[sizeof(SYMBOL_INFO) + 512] {};
		auto* sym         = reinterpret_cast<SYMBOL_INFO*>(buf);
		sym->SizeOfStruct = sizeof(SYMBOL_INFO);
		sym->MaxNameLen   = 511;
		DWORD64 disp      = 0;
		if (SymFromAddr(process, addr, &disp, sym)) r.second = sym->Name;
		return symbols.emplace(addr, r).first->second;
	};
	fprintf(f, "{\"pid\": %lu, \"seconds\": %.2f, \"hz\": %d, \"threads\": [", pid, elapsed, hz);
	bool first_thread = true;
	for (auto& [tid, t]: threads) {
		t.name = ThreadName(t.handle);
		const double cpu_ms = (ThreadCpu100ns(t.handle) - t.cpu_start_100ns) / 10000.0;
		fprintf(f, "%s\n {\"tid\": %lu, \"name\": ", first_thread ? "" : ",", tid);
		first_thread = false;
		JsonString(f, t.name);
		fprintf(f, ", \"cpu_ms\": %.1f, \"samples\": %llu, \"stacks\": [", cpu_ms,
		        static_cast<unsigned long long>(t.samples));
		bool first_stack = true;
		for (const auto& [frames, count]: t.stacks) {
			fprintf(f, "%s{\"count\": %llu, \"frames\": [", first_stack ? "" : ", ",
			        static_cast<unsigned long long>(count));
			first_stack = false;
			for (size_t i = 0; i < frames.size(); i++) {
				const auto& [module, symbol] = resolve(frames[i]);
				fprintf(f, "%s{\"addr\": %llu, \"module\": ", i ? ", " : "",
				        static_cast<unsigned long long>(frames[i]));
				JsonString(f, module);
				fprintf(f, ", \"symbol\": ");
				JsonString(f, symbol);
				fputc('}', f);
			}
			fprintf(f, "]}");
		}
		fprintf(f, "]}");
		CloseHandle(t.handle);
	}
	fprintf(f, "\n]}\n");
	fclose(f);
	SymCleanup(process);
	CloseHandle(process);
	printf("sampler: %zu threads, %.1f s, %d Hz -> %s\n", threads.size(), elapsed, hz, out);
	return 0;
}
