/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-10-04
 */

export const useMarkersStore = defineStore("markers", {
	state: (): MarkersStore => ({
		sheet: {
			groups: [],
			points: [],
			requests: [],
			placing: false,
			draft: false,
			playerCreator: true,
			adminCreator: true,
			isAdmin: false,
			placingMode: false,
			globalCategories: [],
		},
		notice: "",
		noticeKind: "error",
		selected: null,
		searchHits: null,
	}),
	getters: {
		points: (state): MarkerPoint[] => (Array.isArray(state.sheet.points) ? state.sheet.points : []),
		groups: (state): MarkerGroup[] => (Array.isArray(state.sheet.groups) ? state.sheet.groups : []),
		requests: (state): MarkerRequest[] => (Array.isArray(state.sheet.requests) ? state.sheet.requests : []),
	},
	actions: {
		select(id: string | null) {
			this.selected = id;
		},
		setSearchHits(ids: string[] | null) {
			this.searchHits = ids;
		},
		setNotice(text: string, kind: MarkerNoticeKind = "error") {
			this.notice = text;
			this.noticeKind = kind;
		},
		clearNotice() {
			this.notice = "";
		},
		deselectIfMissing(ids: string[]) {
			if (this.selected && !ids.includes(this.selected)) this.selected = null;
		},
	},
});
