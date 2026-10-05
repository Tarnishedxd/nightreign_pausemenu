const CAT_PREFIX = "ui.settings.experimental.categories.";
const SHARED_PREFIX = "ui.settings.experimental.shared.";

type ExpMaps = {
	categories: Record<number, Record<string, string>>;
	shared: Record<string, string>;
};

const emptyMaps: ExpMaps = { categories: {}, shared: {} };

let cacheSource: Record<string, string> | null = null;
let cacheMaps: ExpMaps = emptyMaps;

const buildMaps = (translations: Record<string, string>): ExpMaps => {
	const categories: Record<number, Record<string, string>> = {};
	const shared: Record<string, string> = {};

	for (const key in translations) {
		const value = translations[key];
		if (value == null) continue;

		if (key.startsWith(SHARED_PREFIX)) {
			shared[key.slice(SHARED_PREFIX.length)] = value;
			continue;
		}
		if (!key.startsWith(CAT_PREFIX)) continue;

		const rest = key.slice(CAT_PREFIX.length);
		const dot = rest.indexOf(".");
		if (dot <= 0) continue;

		const index = Number(rest.slice(0, dot));
		if (!Number.isFinite(index)) continue;

		const label = rest.slice(dot + 1);
		(categories[index] ??= {})[label] = value;
	}

	return { categories, shared };
};

const getMaps = (translations: Record<string, string>) => {
	if (cacheSource === translations) return cacheMaps;
	cacheSource = translations;
	cacheMaps = buildMaps(translations);
	return cacheMaps;
};

export const useExperimental = () => {
	const { experimentalLabels } = usePreferences();
	const locale = useLocaleStore();

	const resolve = (categoryIndex: number | undefined, value: string) => {
		if (!value || !experimentalLabels.value) return value;
		const maps = getMaps(locale.translations);
		if (categoryIndex != null) {
			const hit = maps.categories[categoryIndex]?.[value];
			if (hit) return hit;
		}
		return maps.shared[value] || value;
	};

	return {
		sharedLabel: (value: string, categoryIndex?: number) => resolve(categoryIndex, value),
		categoryLabel: (category: SettingsCategory) => {
			if (!experimentalLabels.value) return category.label;
			const title = getMaps(locale.translations).categories[category.index]?._TITLE_;
			return title || category.label;
		},
		settingLabel: (categoryIndex: number, row: GameSettingRow) => resolve(categoryIndex, row.label),
		choiceLabel: (categoryIndex: number, row: GameSettingRow, index: number) =>
			resolve(categoryIndex, row.choices[index] || ""),
	};
};
