/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

/*
 * The fonts a document may name, and the sizes it may give.
 *
 * A run of text carries the id of its font, not a family name: the desktop and
 * Android clients ship the same files under the same ids, so a document reads
 * in the same typeface on every device. The three lists have to be kept in
 * step -- see jami-client-qt/src/app/collabrichbinding.cpp and fonts/README.md.
 */

/** In the order they are offered. `file` is the file name without its style. */
export const DOCUMENT_FONTS = [
    { id: 'liberation-sans', family: 'Liberation Sans', file: 'LiberationSans' },
    { id: 'liberation-serif', family: 'Liberation Serif', file: 'LiberationSerif' },
    { id: 'liberation-mono', family: 'Liberation Mono', file: 'LiberationMono' },
    { id: 'carlito', family: 'Carlito', file: 'Carlito' },
    { id: 'caladea', family: 'Caladea', file: 'Caladea' },
    { id: 'gelasio', family: 'Gelasio', file: 'Gelasio' },
    { id: 'eb-garamond', family: 'EB Garamond', file: 'EBGaramond' },
    { id: 'roboto', family: 'Roboto', file: 'Roboto' },
    { id: 'open-sans', family: 'Open Sans', file: 'OpenSans' },
    { id: 'comic-neue', family: 'Comic Neue', file: 'ComicNeue' },
]

/*
 * Sizes a document may give, in points. A peer's delta can say anything, and
 * text a thousand points tall is a way to make a document unusable for whoever
 * opens it.
 */
export const MIN_FONT_SIZE = 1
export const MAX_FONT_SIZE = 400

/* The sizes offered, as on the desktop. */
export const FONT_SIZES = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72]

/*
 * A font id is a short lowercase name. Whatever is kept is sent again with
 * every character typed into it.
 */
const MAX_FONT_ID_LENGTH = 64
const FONT_ID = /^[a-z0-9-]+$/

/**
 * The font id @p value names, or '' when it is not one a document may hold.
 *
 * An id this client does not ship is still an id: it is kept and passed on,
 * so that an edit made here does not quietly drop what a newer client chose.
 */
export function fontIdOf(value) {
    if (typeof value !== 'string') return ''
    if (value.length > MAX_FONT_ID_LENGTH || !FONT_ID.test(value)) return ''
    return value
}

/** The size @p value gives in points, or 0 when it gives none a document may have. */
export function fontSizeOf(value) {
    if (typeof value !== 'number' || !Number.isFinite(value)) return 0
    return value >= MIN_FONT_SIZE && value <= MAX_FONT_SIZE ? value : 0
}

/** The shipped font @p id names, or null. */
export function documentFont(id) {
    return DOCUMENT_FONTS.find((font) => font.id === id) || null
}

const STYLES = [
    { suffix: 'Regular', weight: 'normal', style: 'normal' },
    { suffix: 'Bold', weight: 'bold', style: 'normal' },
    { suffix: 'Italic', weight: 'normal', style: 'italic' },
    { suffix: 'BoldItalic', weight: 'bold', style: 'italic' },
]

/**
 * The style sheet that draws text in the shipped fonts.
 *
 * A face is declared for each file, which the page fetches only once text set
 * in it is on screen: most documents use none of them. A character the font
 * lacks -- an emoji, a script it does not cover -- falls back to the editor's
 * own font, as it would anywhere else.
 *
 * The faces are declared under names of their own: the editor's own font is
 * Roboto when the system has it, and a face declared as "Roboto" would take
 * its place for every document, chosen or not.
 *
 * @param base where the font files are served from, ending with a slash.
 * @param fallback the editor's own font-family list.
 */
export function fontStyleSheet(base, fallback) {
    const rules = []
    for (const font of DOCUMENT_FONTS) {
        const family = `Jami ${font.family}`
        for (const face of STYLES) {
            rules.push(`@font-face { font-family: "${family}"; `
                + `src: url("${base}${font.file}-${face.suffix}.ttf") format("truetype"); `
                + `font-weight: ${face.weight}; font-style: ${face.style}; }`)
        }
        rules.push(`.ql-editor [data-font="${font.id}"] { `
            + `font-family: "${family}", ${fallback}; }`)
    }
    return rules.join('\n')
}
