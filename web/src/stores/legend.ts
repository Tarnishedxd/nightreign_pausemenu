/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-10-04
 */

export const useLegendStore = defineStore("legend", {
	state: (): LegendStore => ({
		legend: {
			status: "idle",
			rows: [],
			groups: [],
			toast: {
				token: 0,
				kind: "",
				label: "",
				cycle: 0,
				count: 0,
			},
			focus: -1,
		},
	}),
});
