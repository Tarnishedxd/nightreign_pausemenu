import { blipSpriteId } from "@/utils/blips";
import { blipColourHex } from "@/utils/blipColours";

export type BlipDraft = {
	label: string;
	sprite: string;
	blipColour: number;
	showOn2d: boolean;
	scale: number;
	shortRange: boolean;
};

export type GlobalBlipDraft = BlipDraft & {
	category: string;
};

export const buildBlipPayload = (draft: BlipDraft) => ({
	label: draft.label,
	sprite: draft.sprite,
	spriteId: blipSpriteId(draft.sprite),
	colour: blipColourHex(draft.blipColour),
	showOn2d: draft.showOn2d,
	blipColour: draft.blipColour,
	scale: draft.scale,
	shortRange: draft.shortRange,
});

export const buildGlobalBlipPayload = (draft: GlobalBlipDraft) => ({
	category: draft.category,
	...buildBlipPayload(draft),
});
