export type Hsv = { h: number; s: number; v: number };

export const hexToHsv = (hex: string): Hsv => {
	const red = Number.parseInt(hex.slice(1, 3), 16) / 255;
	const green = Number.parseInt(hex.slice(3, 5), 16) / 255;
	const blue = Number.parseInt(hex.slice(5, 7), 16) / 255;
	const max = Math.max(red, green, blue);
	const min = Math.min(red, green, blue);
	const delta = max - min;
	let nextHue = 0;
	if (delta !== 0) {
		if (max === red) nextHue = ((green - blue) / delta) % 6;
		else if (max === green) nextHue = (blue - red) / delta + 2;
		else nextHue = (red - green) / delta + 4;
		nextHue *= 60;
		if (nextHue < 0) nextHue += 360;
	}
	return { h: nextHue, s: max === 0 ? 0 : delta / max, v: max };
};

export const hsvToHex = (nextHue: number, nextSat: number, nextVal: number) => {
	const chroma = nextVal * nextSat;
	const x = chroma * (1 - Math.abs(((nextHue / 60) % 2) - 1));
	const match = nextVal - chroma;
	let red = 0;
	let green = 0;
	let blue = 0;
	if (nextHue < 60) [red, green, blue] = [chroma, x, 0];
	else if (nextHue < 120) [red, green, blue] = [x, chroma, 0];
	else if (nextHue < 180) [red, green, blue] = [0, chroma, x];
	else if (nextHue < 240) [red, green, blue] = [0, x, chroma];
	else if (nextHue < 300) [red, green, blue] = [x, 0, chroma];
	else [red, green, blue] = [chroma, 0, x];
	const channel = (value: number) =>
		Math.round((value + match) * 255)
			.toString(16)
			.padStart(2, "0");
	return `#${channel(red)}${channel(green)}${channel(blue)}`;
};

/** Ink color for contrast against a hex background (0–255 luminance scale). */
export const readableInk = (hex: string, threshold = 160) => {
	const red = Number.parseInt(hex.slice(1, 3), 16);
	const green = Number.parseInt(hex.slice(3, 5), 16);
	const blue = Number.parseInt(hex.slice(5, 7), 16);
	const luminance = (red * 299 + green * 587 + blue * 114) / 1000;
	return luminance > threshold ? "#151515" : "#fafafa";
};

/** Relative luminance 0–1 using Rec.601 weights. */
export const relativeLuminance = (red: number, green: number, blue: number) =>
	(red * 0.299 + green * 0.587 + blue * 0.114) / 255;
