/**
 * A scrolling list that fades out at an edge with more rows past it, instead of cutting a row in
 * half under whatever sits above it (the 3D map's "Blips" header, the map's search box).
 */
export const useScrollFade = (size = "24px") => {
	const listRef = ref<HTMLElement>();
	const fadeTop = ref(false);
	const fadeBottom = ref(false);

	const updateFade = () => {
		const el = listRef.value;
		if (!el) return;
		fadeTop.value = el.scrollTop > 1;
		fadeBottom.value = el.scrollTop + el.clientHeight < el.scrollHeight - 1;
	};

	const listMask = computed(() => {
		if (!fadeTop.value && !fadeBottom.value) return {};
		const top = fadeTop.value ? `transparent 0, #000 ${size}` : "#000 0";
		const bottom = fadeBottom.value ? `#000 calc(100% - ${size}), transparent 100%` : "#000 100%";
		const mask = `linear-gradient(to bottom, ${top}, ${bottom})`;
		return { maskImage: mask, WebkitMaskImage: mask };
	});

	// rows coming and going (and groups folding) change what is past the edges
	let frame = 0;
	const soon = () => {
		if (frame) return;
		frame = requestAnimationFrame(() => {
			frame = 0;
			updateFade();
		});
	};
	let resize: ResizeObserver | null = null;
	let rows: MutationObserver | null = null;
	const disconnect = () => {
		resize?.disconnect();
		rows?.disconnect();
		resize = rows = null;
	};
	watch(listRef, (el) => {
		disconnect();
		if (!el) return;
		resize = new ResizeObserver(soon);
		resize.observe(el);
		rows = new MutationObserver(soon);
		rows.observe(el, { childList: true, subtree: true });
		updateFade();
	});
	onBeforeUnmount(() => {
		disconnect();
		if (frame) cancelAnimationFrame(frame);
	});

	return { listRef, listMask, updateFade };
};
