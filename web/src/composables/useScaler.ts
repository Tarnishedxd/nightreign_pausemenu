/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-06-29
 */

const ROOT_PX = 16;
export const uiScaleFactor = ref(1);

type UseScalerOptions = {
	clearOnUnmount?: boolean;
};

/**
 * Use the scaler to apply the UI scale factor to the document element
 * @param scale The scale factor to apply
 * @param onApply A callback function to call when the scale factor is applied
 * @param options Options for the scaler
 * @returns An object with the apply and clear functions
 */
export function useScaler(scale: Ref<number> | number, onApply?: () => void, options: UseScalerOptions = {}) {
	const apply = () => {
		const base = Math.max(0.5, Math.min(window.innerHeight / 1080, 2.5));
		uiScaleFactor.value = base * (typeof scale === "number" ? scale / 100 : scale.value / 100);
		document.documentElement.style.fontSize = `${Math.round(ROOT_PX * uiScaleFactor.value)}px`;
		onApply?.();
	};

	const clear = () => {
		document.documentElement.style.fontSize = "";
		uiScaleFactor.value = 1;
	};

	onMounted(() => {
		apply();
		window.addEventListener("resize", apply);
	});

	onUnmounted(() => {
		window.removeEventListener("resize", apply);
		if (options.clearOnUnmount !== false) {
			clear();
		}
	});

	watch(typeof scale === "number" ? ref(scale) : scale, apply);

	return { apply, clear };
}

/**
 * Calculate the icon size in pixels based on the UI scale factor
 * @param size Icon size in pixels
 * @returns
 */
export function iS(size: number): number {
	return Math.round(size * uiScaleFactor.value);
}
