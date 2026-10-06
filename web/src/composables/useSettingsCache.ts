/**
 * GTA needs a second or more to build its settings frontend every time the page opens, and
 * again whenever a category (above all Key Bindings) is entered. The NUI page lives for the
 * whole game session, so the last categories / rows seen are kept here and shown read-only
 * while the game catches up.
 */

type SettingsCache = {
	categories: SettingsCategory[];
	/** Game setting rows by category id. */
	rows: Record<string, GameSettingRow[]>;
	/** Category ids that are key binding pages. */
	keyCategories: Record<string, true>;
	/** Key groups by category id. */
	keyGroups: Record<string, KeyBindingGroup[]>;
	/** Key binding rows by group id. */
	keyRows: Record<string, KeyBindingRow[]>;
	/** Last group seen per key binding category. */
	lastKeyGroup: Record<string, string>;
};

const cache = shallowReactive<SettingsCache>({
	categories: [],
	rows: {},
	keyCategories: {},
	keyGroups: {},
	keyRows: {},
	lastKeyGroup: {},
});

const remember = (state: SettingsState) => {
	if (state.categories.length) {
		cache.categories = state.categories.map((category) => ({ ...toRaw(category), pending: 0 }));
	}
	const id = state.activeCategoryId;
	if (state.status !== "ready" || !id || !state.rows.length) return;

	if (!state.keyBindings) {
		cache.rows = {
			...cache.rows,
			[id]: state.rows
				.filter((row): row is GameSettingRow => row.type === "setting")
				.map((row) => ({ ...toRaw(row), editable: false, pending: false })),
		};
		return;
	}

	cache.keyCategories = { ...cache.keyCategories, [id]: true };
	if (state.keyGroups.length > 1) {
		cache.keyGroups = { ...cache.keyGroups, [id]: state.keyGroups.map((group) => ({ ...toRaw(group) })) };
	}
	const byGroup: Record<string, KeyBindingRow[]> = {};
	for (const row of state.rows) {
		if (row.type !== "keybind" || !row.groupId) continue;
		(byGroup[row.groupId] ??= []).push({ ...toRaw(row), editable: false });
	}
	cache.keyRows = { ...cache.keyRows, ...byGroup };
	if (state.activeKeyGroupId) cache.lastKeyGroup = { ...cache.lastKeyGroup, [id]: state.activeKeyGroupId };
};

/** The group a key binding page opens on: GTA starts on the first one. */
const previewKeyGroup = (categoryId: string) => {
	const groups = cache.keyGroups[categoryId] ?? [];
	const first = groups[0]?.id;
	if (first && cache.keyRows[first]?.length) return first;
	const last = cache.lastKeyGroup[categoryId];
	return last && cache.keyRows[last]?.length ? last : "";
};

const hasPreview = (categoryId: string) => {
	if (!categoryId) return false;
	if (cache.keyCategories[categoryId]) return !!previewKeyGroup(categoryId) && (cache.keyGroups[categoryId]?.length ?? 0) > 1;
	return (cache.rows[categoryId]?.length ?? 0) > 0;
};

export const useSettingsCache = () => ({ cache, remember, previewKeyGroup, hasPreview });
