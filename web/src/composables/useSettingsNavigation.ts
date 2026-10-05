type FocusZone = "categories" | "groups" | "rows";

type SettingsNavigationOptions = {
	focusZone: Ref<FocusZone>;
	categoryCursor: Ref<number>;
	groupCursor: Ref<number>;
	selectedId: Ref<string>;
	view: Ref<"settings" | "preferences">;
	customizeOrder: string[];
	alertOpen: () => boolean;
	listenActive: () => boolean;
	busy: () => boolean;
	pendingCount: () => number;
	keyBindings: () => boolean;
	keyGroups: () => { id: string }[];
	categoriesCount: () => number;
	navigableRows: () => { id: string }[];
	selectedRow: () => SettingsRow | undefined;
	editPane: Ref<{ nudge: (direction: number) => void; activate: () => void } | null>;
	onGroupEnter: (id: string, index: number) => void;
	onEnterCategory: () => void | Promise<void>;
	onGoBack: () => void;
	onApply: () => void;
	onChangeSetting: (row: GameSettingRow, direction: number) => void;
	onActivateSetting: (row: GameSettingRow) => void;
	onStartListen: (row: KeyBindingRow) => void;
};

export const useSettingsNavigation = (options: SettingsNavigationOptions) => {
	const moveList = (direction: number) => {
		const rows =
			options.view.value === "preferences" ? options.customizeOrder.map((id) => ({ id })) : options.navigableRows();
		if (!rows.length) return;
		const index = rows.findIndex((row) => row.id === options.selectedId.value);
		const start = index < 0 ? (direction > 0 ? -1 : 0) : index;
		options.selectedId.value = rows[(start + direction + rows.length) % rows.length]?.id ?? "";
	};

	const onKeyDown = (event: KeyboardEvent) => {
		if (options.alertOpen()) return;
		if (options.listenActive()) return;
		if (event.target instanceof HTMLInputElement) {
			if (event.key === "Escape") event.target.blur();
			return;
		}
		if (event.key === "Escape") {
			options.onGoBack();
			return;
		}
		if (event.key === " " || event.key === "Spacebar") {
			if (!options.pendingCount() || options.busy()) return;
			event.preventDefault();
			options.onApply();
			return;
		}
		if (event.key === "Backspace") {
			event.preventDefault();
			if (options.focusZone.value === "rows" && options.keyBindings()) options.focusZone.value = "groups";
			else if (options.focusZone.value === "rows" || options.focusZone.value === "groups") {
				options.focusZone.value = "categories";
			}
			return;
		}
		if (options.focusZone.value === "groups") {
			const count = options.keyGroups().length;
			if (!count) return;
			if (event.key === "ArrowDown" || event.key === "ArrowUp") {
				event.preventDefault();
				const direction = event.key === "ArrowDown" ? 1 : -1;
				options.groupCursor.value = (options.groupCursor.value + direction + count) % count;
			}
			if (event.key === "Enter") {
				event.preventDefault();
				const group = options.keyGroups()[options.groupCursor.value];
				if (group) options.onGroupEnter(group.id, options.groupCursor.value);
			}
			return;
		}
		if (options.focusZone.value === "categories") {
			const count = options.categoriesCount() + 2;
			if (event.key === "ArrowDown" || event.key === "ArrowUp") {
				event.preventDefault();
				const direction = event.key === "ArrowDown" ? 1 : -1;
				options.categoryCursor.value = (options.categoryCursor.value + direction + count) % count;
			}
			if (event.key === "Enter") {
				event.preventDefault();
				void options.onEnterCategory();
			}
			return;
		}
		if (event.key === "ArrowDown" || event.key === "ArrowUp") {
			event.preventDefault();
			moveList(event.key === "ArrowDown" ? 1 : -1);
			return;
		}
		if (options.view.value === "preferences") {
			if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
				event.preventDefault();
				options.editPane.value?.nudge(event.key === "ArrowRight" ? 1 : -1);
			}
			if (event.key === "Enter") {
				event.preventDefault();
				options.editPane.value?.activate();
			}
			return;
		}
		const row = options.selectedRow();
		if (row?.type === "setting" && (event.key === "ArrowLeft" || event.key === "ArrowRight")) {
			event.preventDefault();
			options.onChangeSetting(row, event.key === "ArrowRight" ? 1 : -1);
		}
		if (event.key === "Enter" && row?.type === "setting" && row.kind === "button") {
			event.preventDefault();
			options.onActivateSetting(row);
		}
		if (event.key === "Enter" && row?.type === "keybind") {
			event.preventDefault();
			options.onStartListen(row);
		}
	};

	return { moveList, onKeyDown };
};
