# Artwork

The textures are World of Warcraft artwork © Blizzard Entertainment. The frame borders, backgrounds, level badge and elite dragons were extracted from WoW: Forever. The combat textures come from the unit frame artwork shipped with the game.

The packaged crops come from [DragonUI's unit frame artwork](https://github.com/NeticSoul/DragonUI/tree/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/Textures/UnitFrames/Forever). See [DragonUI's third-party notices](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/THIRD_PARTY_NOTICES.md) for the source of each texture.

The gryphons are the Alliance end caps on the WoW: Forever action bar sheet. The packaged texture comes from [DragonUI's action bar artwork](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/Textures/ActionBars/uiactionbar2x_forever.blp).

The round minimap ring comes from [DragonUI's WoW: Forever minimap artwork](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/Textures/Minimap/forever_circle.tga).

The level badge was generated from the supplied bronze medallion reference.

The player and target frame art and their rest and death indicators were generated from the supplied frame reference.

The backpack frame, slot trim, title strip and close button were generated from the supplied backpack reference. The search icon uses the local WeakAuras CommonSearch texture.

The cast bar artwork comes from [DragonUI's copy of Blizzard's cast bar atlas](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/Textures/Castbar/uicastingbar2x.tga).

The colored micro menu sprites and PvP emblems come from [DragonUI's micro menu artwork](https://github.com/NeticSoul/DragonUI/tree/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/Textures/Micromenu). The textured target name strip comes from the Forever unit frame artwork linked above.

The shop cart sprite in the micro menu atlas comes from the Nozdor client's Trading Post texture.

FadeLeft.tga and FadeRight.tga are unmodified copies from the installed SharedMedia texture pack.

The bundled library contains the media from the installed SharedMedia 3.3.5a Cyrillic & Custom Edition, registered under their original names. LibSharedMedia-3.0 is by Elkano. The bundled libraries retain their original headers.

The cursor effects and textures come from the installed CursorUZ 1.0.0 addon.

The optional cast bar style, minimap header, day/night indicator and group-finder eye, and action-bar progress borders use artwork from the locally installed MidUI.

The action-bar slot borders and embossed empty slots are warm-toned crops of Blizzard artwork from [pretty_actionbar's action-bar atlas](https://github.com/s0h2x/pretty_actionbar/blob/master/assets/uiactionbar2x_new.blp).

`DamageMeter.tga` contains unretouched sprites from Blizzard's WoW: Forever client build 1.60.1.70862, using the [UI atlas metadata](https://wago.tools/db2/UiTextureAtlasMember?build=1.60.1.70862). The source FileDataIDs are 7499557 (meter), 8165540 (row fill), 8069110 (dropdown buttons), 7518368 (settings button), 8268353 (collapse and expand buttons), and 1662186 (class icons).

`Nameplate-Chrome.tga` is an uncompressed 512 × 128 atlas with single-bevel steel trim for the health bar and level badge, an external threat halo mask and the aura trim. The elite icon uses Blizzard's built-in WotLK `Interface\Tooltips\elitenameplateicon`.

`Art/Nameplates` contains the seven unmodified textures from the local WoW Forever Nameplates 1.66.00 donor (`Interface/WoWForeverNameplates/Media`). `PlateBoxes30300.tga` packs its three 64 × 48 box sprites into a power-of-two atlas for the 3.3.5a renderer. The backport uses the existing `Nameplate-Chrome.tga` aura trim.

`ActionBar/Retail-EndCaps-Alliance.blp`, `ActionBar/Retail-EndCaps-Horde.blp` (Dragonflight-style gryphons and wyverns, cells 356 x 334 on a 512 x 1024 sheet) and `ActionBar/Retail-Bags.blp` (backpack picture and bag rings, 512 x 128) are copied unchanged from [DragonUI](https://github.com/NeticSoul/DragonUI) (`Textures/ActionBars/uiactionbar2x_new.blp`, `uiactionbar2x_new2.blp` and `Textures/Bags/bagslots2x.blp`), which is MIT licensed, Copyright (c) 2026 NeticSoul and DragonUI contributors. The texture cells are listed in DragonUI's `utils/atlas.lua`.

`ActionBar/Retail-XP.blp` (experience bar background and border, 1024 x 256) and `ActionBar/Retail-Micro.blp` (flat micro menu icons, 256 x 512) are copied unchanged from DragonUI (`Textures/XP/uiexperiencebar.blp` and `Textures/Micromenu/Atlas/uimicromenu2x.blp`, MIT).

`UnitFrames/Retail-*` (player, target and target-of-target background and border art, and the player status, player combat and target combat glows) are copied unchanged from DragonUI (`Textures/UnitFrames/HD/` (Player, Target and TargetofTarget BACKGROUND and BORDER), `Textures/UnitFrames/Forever/Player-Status.tga`, `Player-InCombat.tga` and `Textures/UnitFrames/Target/ui-hud-unitframe-target-portraiton-incombat-2x.blp`, MIT). They are used only by the Retail layout; their geometry is taken from DragonUI's `modules/unitframes/uf_skins.lua`.

`Map/Retail-Border.tga` (silver minimap ring with gold compass marks, 256 x 256) is copied unchanged from DragonUI (`Textures/Minimap/uiminimapborder.tga`, MIT). The Retail chat input box follows DragonUI's `modules/chatmods.lua` (flat dark box, no art).
