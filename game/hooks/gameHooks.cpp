// SPDX-License-Identifier: GPL-2.0-only
// desport: HLE overrides specific to Demon's Souls (PPSA01341, ADR-001).
//
// Functions registered here win over the engine's HLE and over the game's native modules
// (Desport::FindGameHook, consulted first in RuntimeLinker::Resolve). They are matched by NID
// and symbol type. Prefer fixing the engine for general bugs; use this for behaviour that only
// this game needs. Every override is recorded in docs/FIXES.md with evidence.
//
// Example (do not enable without evidence):
//   LIB_VERSION("desport", 1, "desport", 1, 1);   // at namespace scope, once
//   static int KYTY_SYSV_ABI MyOverride(int arg) { PRINT_NAME(); return 0; }
//   LIB_FUNC("<nid>", MyOverride);                // inside RegisterGameHooks
#include "libs/libs.h"
#include "loader/desport.h"
#include "loader/symbolDatabase.h"

namespace Desport {

namespace {
constexpr char TargetTitleId[] = "PPSA01341";
} // namespace

void RegisterGameHooks(Loader::SymbolDatabase* s, const std::string& title_id) {
	if (title_id != TargetTitleId) {
		return;
	}
	(void)s;
	// No overrides yet.
}

} // namespace Desport
