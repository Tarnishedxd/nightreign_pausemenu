export type Preferences = {
	primary: string;
	experimentalLabels: boolean;
	darkMode: boolean;
};

const PREFERENCES_KEY = "0r-pausemenu:panel";

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
