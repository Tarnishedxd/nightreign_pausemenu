/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-10-04
 */

export const useSettingsStore = defineStore("settings", {
	state: (): SettingsStore => ({
		settings: {
			status: "idle",
			build: "",
			error: "",
			categories: [],
			activeCategoryId: "",
			rows: [],
			version: 0,
			busy: false,
			keyBindings: false,
			keyGroups: [],
			activeKeyGroupId: "",
			listenIndex: -1,
			listenSlot: "",
			listenPhase: "",
			keyPrompt: false,
			vram: "",
			vramPercent: -1,
			pendingCount: 0,
			veil: false,
		},
		alert: {
			open: false,
			title: "",
			body: "",
			prompt: "",
			detail: "",
			buttons: [],
		},
	}),
});
