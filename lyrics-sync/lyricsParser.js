/**
 * LRC Lyrics Parser
 * Parses standard LRC format and enhanced LRC with translations
 */

/**
 * Parse LRC content into structured lyrics data
 * @param {string} content - Raw LRC file content
 * @returns {object} - { lyrics: [{time, text, translation}], metadata: {}, error: string|null }
 */
function parseLrc(content) {
    if (!content || typeof content !== 'string') {
        return { lyrics: [], metadata: {}, error: "Empty or invalid content" };
    }

    const lines = content.split('\n');
    const lyrics = [];
    const metadata = {};
    const translationMap = {}; // Store translations by timestamp

    // Regex patterns
    const timeTagRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/g;
    const metadataRegex = /^\[([a-zA-Z]+):(.+)\]$/;
    const lineWithTimeRegex = /^((?:\[\d{2}:\d{2}\.\d{2,3}\])+)(.*)$/;

    // First pass: parse all lines
    for (let line of lines) {
        line = line.trim();
        if (!line) continue;

        // Check for metadata tags like [ar:Artist], [ti:Title], etc.
        const metaMatch = line.match(metadataRegex);
        if (metaMatch && !line.match(/\[\d{2}:\d{2}/)) {
            const key = metaMatch[1].toLowerCase();
            const value = metaMatch[2].trim();
            metadata[key] = value;
            continue;
        }

        // Check for timed lyrics
        const lineMatch = line.match(lineWithTimeRegex);
        if (lineMatch) {
            const timeTags = lineMatch[1];
            const text = lineMatch[2].trim();

            // Extract all time tags (some lines have multiple)
            let match;
            const times = [];
            timeTagRegex.lastIndex = 0;
            while ((match = timeTagRegex.exec(timeTags)) !== null) {
                const minutes = parseInt(match[1], 10);
                const seconds = parseInt(match[2], 10);
                const ms = parseInt(match[3].padEnd(3, '0').slice(0, 3), 10);
                const totalMs = minutes * 60000 + seconds * 1000 + ms;
                times.push(totalMs);
            }

            // Add each time-text pair
            for (const time of times) {
                lyrics.push({ time, text, translation: "" });
            }
        }
    }

    // Sort by time
    lyrics.sort((a, b) => a.time - b.time);

    // Second pass: detect and merge translations
    // Common pattern: same timestamp with different text (one is translation)
    // Or lines starting with translation markers
    mergeTranslations(lyrics);

    // Remove empty lines at start
    while (lyrics.length > 0 && !lyrics[0].text) {
        lyrics.shift();
    }

    return {
        lyrics,
        metadata,
        error: lyrics.length === 0 ? "No lyrics found in file" : null
    };
}

/**
 * Merge translations for dual-language lyrics
 * Detects patterns where translations share the same timestamp
 */
function mergeTranslations(lyrics) {
    const timeMap = new Map();

    // Group by timestamp
    for (let i = 0; i < lyrics.length; i++) {
        const time = lyrics[i].time;
        if (!timeMap.has(time)) {
            timeMap.set(time, []);
        }
        timeMap.get(time).push(i);
    }

    // For timestamps with multiple entries, try to identify translation
    const toRemove = new Set();
    
    for (const [time, indices] of timeMap) {
        if (indices.length === 2) {
            const line1 = lyrics[indices[0]];
            const line2 = lyrics[indices[1]];

            // Heuristic: if one line is primarily CJK and other is not, 
            // the non-CJK might be translation (or vice versa)
            const isCJK1 = hasCJK(line1.text);
            const isCJK2 = hasCJK(line2.text);

            if (isCJK1 !== isCJK2) {
                // Assume CJK is original, other is translation
                if (isCJK1) {
                    line1.translation = line2.text;
                    toRemove.add(indices[1]);
                } else {
                    line2.translation = line1.text;
                    toRemove.add(indices[0]);
                }
            }
        }
    }

    // Remove merged translation lines (in reverse order to preserve indices)
    const removeIndices = Array.from(toRemove).sort((a, b) => b - a);
    for (const idx of removeIndices) {
        lyrics.splice(idx, 1);
    }
}

/**
 * Check if string contains CJK characters
 */
function hasCJK(str) {
    if (!str) return false;
    // CJK Unified Ideographs, Hiragana, Katakana, Hangul
    return /[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]/.test(str);
}

/**
 * Format milliseconds to mm:ss format
 */
function formatTime(ms) {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
}

/**
 * Find the current line index for a given position
 * @param {Array} lyrics - Parsed lyrics array
 * @param {number} positionMs - Current position in milliseconds
 * @returns {number} - Index of current line, or -1 if before first line
 */
function findCurrentLine(lyrics, positionMs) {
    if (!lyrics || lyrics.length === 0) return -1;
    
    for (let i = lyrics.length - 1; i >= 0; i--) {
        if (lyrics[i].time <= positionMs) {
            return i;
        }
    }
    return -1;
}
