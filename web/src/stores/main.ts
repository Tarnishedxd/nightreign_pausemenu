/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-05-21
 */

export const useMainStore = defineStore("main", {
	state: (): MainStore => ({
		visible: isEnvBrowser(),
		currentPage: "pause",
		quitConfirm: false,
		cover: false,
		player: {
			source: 0,
			name: "",
			serverName: "",
			cash: 0,
			bank: 0,
			premium: -1,
			players: 0,
			maxPlayers: 0,
			currency: "USD",
			currencyFormat: "en-US",
			enable3DMap: true,
			showBranding: true,
			showStats: false,
			showPlayerCount: false,
		},
		map: {
			zone: "",
			street: "",
			altitude: 0,
		},
	}),
	actions: {
		updateVisibility(visibility: boolean) {
			this.visible = visibility;
		},
		updatePage(page: Page) {
			this.currentPage = page;
		},
		updateQuitConfirm(confirm: boolean) {
			this.quitConfirm = confirm;
		},
		updateCover(cover: boolean) {
			this.cover = cover;
		},
	},
});
