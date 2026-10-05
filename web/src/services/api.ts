/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-06-16
 */

let readyRetry = 0;

/**
 * Tells the client script that the UI is up. Retried until it succeeds, and repeated whenever the
 * client pings (`ltbridge_check_nui`), so a signal sent before the client registered its callback is not lost.
 */
export const announceReady = () => {
	window.clearTimeout(readyRetry);
	fetchNui("ltbridge:ready", {}, "ok").catch(() => {
		readyRetry = window.setTimeout(announceReady, 500);
	});
};

onNuiMessage((data: any) => {
	const main = useMainStore();
	const settings = useSettingsStore();
	const locale = useLocaleStore();
	const legend = useLegendStore();
	switch (data.action) {
		case "UpdatePlayer":
			main.$patch((s) =>
				applyLtBatch(s.player, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdatePlayer_sync":
		case "UpdatePlayer_set":
			main.$state.player = replaceLtState(main.$state.player, data.state ?? {});
			break;
		case "UpdateMap":
			main.$patch((s) =>
				applyLtBatch(s.map, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdateMap_sync":
		case "UpdateMap_set":
			main.$state.map = replaceLtState(main.$state.map, data.state ?? {});
			break;
		case "UpdateSettings":
			settings.$patch((s) =>
				applyLtBatch(s.settings, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdateSettings_sync":
		case "UpdateSettings_set":
			settings.$state.settings = replaceLtState(settings.$state.settings, data.state ?? {});
			break;
		case "UpdateGtaAlert":
			settings.$patch((s) =>
				applyLtBatch(s.alert, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdateGtaAlert_sync":
		case "UpdateGtaAlert_set":
			settings.$state.alert = replaceLtState(settings.$state.alert, data.state ?? {});
			break;
		case "UpdateLocale":
			if (!data.locale || !data.translations) return;
			locale.updateLocale(data.locale);
			locale.updateTranslations(data.translations);
			break;
		case "UpdateVisibility":
			main.updateVisibility(data.visible);
			break;
		case "UpdatePage":
			if (data.page) main.updatePage(data.page);
			break;
		case "UpdateQuitConfirm":
			main.updateQuitConfirm(!!data.confirm);
			break;
		case "UpdateLegend":
			legend.$patch((s) =>
				applyLtBatch(s.legend, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdateLegend_sync":
		case "UpdateLegend_set":
			legend.$state.legend = replaceLtState(legend.$state.legend, data.state ?? {});
			break;
		case "UpdateMarkers":
			useMarkersStore().$patch((s) =>
				applyLtBatch(s.sheet, {
					batch: data.batch,
					deletes: data.deletes,
				}),
			);
			break;
		case "UpdateMarkers_sync":
		case "UpdateMarkers_set":
			useMarkersStore().sheet = replaceLtState(useMarkersStore().sheet, data.state ?? {});
			break;
		case "UpdateMarkerNotice":
			useMarkersStore().setNotice(data.text || "", data.kind === "success" ? "success" : "error");
			break;
		case "UpdateMarkerPositions":
			break;
		case "ltbridge_check_nui":
			announceReady();
			break;
		default:
			console.error(`[NUI] Unknown action: ${data.action}`);
			break;
	}
});
