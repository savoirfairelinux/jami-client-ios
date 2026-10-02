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
 * A run of text carries the id of a generic family, the same on every client.
 * Each client draws it in the font its platform gives that family.
 */

/** In the order they are offered. */
export const DOCUMENT_FONTS = [
    { id: 'sans-serif', family: 'Sans Serif', stack: 'sans-serif' },
    { id: 'serif', family: 'Serif', stack: 'serif' },
    { id: 'monospace', family: 'Monospace', stack: 'monospace' },
    { id: 'cursive', family: 'Cursive', stack: 'cursive' },
]

/*
 * Sizes a document may give, in points. A peer's delta can say anything, and
 * text a thousand points tall is a way to make a document unusable for whoever
 * opens it.
 */
export const MIN_FONT_SIZE = 1
export const MAX_FONT_SIZE = 400

/*
 * A font id is a short lowercase name. Whatever is kept is sent again with
 * every character typed into it.
 */
const MAX_FONT_ID_LENGTH = 64
const FONT_ID = /^[a-z0-9-]+$/

/**
 * The font id @p value names, or '' when it is not one a document may hold.
 *
 * An id this client does not offer is still an id: it is kept and passed on,
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

/** The offered font @p id names, or null. */
export function documentFont(id) {
    return DOCUMENT_FONTS.find((font) => font.id === id) || null
}

/** The style sheet that draws text in the offered fonts. */
export function fontStyleSheet() {
    return DOCUMENT_FONTS.map((font) =>
        `.ql-editor [data-font="${font.id}"] { font-family: ${font.stack}; }`).join('\n')
}
