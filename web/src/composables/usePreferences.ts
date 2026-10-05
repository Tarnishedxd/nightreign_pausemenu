export type Preferences = {
	primary: string;
	experimentalLabels: boolean;
	darkMode: boolean;
};

const PREFERENCES_KEY = "nightreign_pausemenu:panel";
export const EXP_LANG_DISMISS_KEY = "nightreign_pausemenu:exp-lang-dismiss";

// Carry values saved under the old resource name over to the new keys once.
const legacyStorageKeys: [string, string][] = [
	["0r-pausemenu:panel", PREFERENCES_KEY],
	["0r-pausemenu:exp-lang-dismiss", EXP_LANG_DISMISS_KEY],
];
try {
	for (const [legacy, current] of legacyStorageKeys) {
		const value = localStorage.getItem(legacy);
		if (value !== null && localStorage.getItem(current) === null) localStorage.setItem(current, value);
		localStorage.removeItem(legacy);
	}
} catch {
	// Storage can be unavailable; defaults are used then.
}

const preferencesDefaults: Preferences = {
	primary: "#fafafa",
	experimentalLabels: true,
	darkMode: false,
};

const hexColor = /^#[0-9a-fA-F]{6}$/;

const rowSurface = (dark: boolean) =>
	dark
		? {
				"--panel-row-bg": "rgb(10 10 10 / 0.2)",
				"--panel-row-bg-focus": "rgb(10 10 10 / 0.4)",
				"--panel-row-bg-hover": "rgb(10 10 10 / 0.2)",
				"--panel-row-border": "rgb(255 255 255 / 0.05)",
				"--panel-row-shadow": "inset 0 0 6px rgb(10 10 10 / 0.15)",
			}
		: {
				"--panel-row-bg": "rgb(255 255 255 / 0.10)",
				"--panel-row-bg-focus": "rgb(255 255 255 / 0.20)",
				"--panel-row-bg-hover": "rgb(255 255 255 / 0.14)",
				"--panel-row-border": "rgb(255 255 255 / 0.10)",
				"--panel-row-shadow": "inset 0 0 6px rgb(255 255 255 / 0.04)",
			};

export const usePreferences = () => {
	const theme = useStorage<Preferences>(PREFERENCES_KEY, { ...preferencesDefaults }, localStorage, {
		mergeDefaults: true,
	});

	const primary = computed({
		get: () => (hexColor.test(theme.value.primary) ? theme.value.primary.toLowerCase() : preferencesDefaults.primary),
		set: (value: string) => {
			if (hexColor.test(value)) theme.value.primary = value.toLowerCase();
		},
	});

	const experimentalLabels = computed({
		get: () => theme.value.experimentalLabels !== false,
		set: (value: boolean) => {
			theme.value.experimentalLabels = value;
		},
	});

	const darkMode = computed({
		get: () => theme.value.darkMode === true,
		set: (value: boolean) => {
			theme.value.darkMode = value;
		},
	});

	const panelStyle = computed(() => ({
		"--panel-primary": primary.value,
		"--panel-ink": readableInk(primary.value),
		...rowSurface(darkMode.value),
	}));

	const resetPanelTheme = () => {
		theme.value = { ...preferencesDefaults };
	};

	return { primary, experimentalLabels, darkMode, panelStyle, resetPanelTheme };
};
