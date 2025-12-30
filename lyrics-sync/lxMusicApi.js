/**
 * LX Music API Client
 * Connects to LX Music Desktop's Open API for real-time lyrics sync
 * 
 * API Documentation: https://lxmusic.toside.cn/desktop/open-api
 */

// Default configuration
const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 23330;

/**
 * Build API URL
 */
function buildUrl(host, port, endpoint) {
    return "http://" + (host || DEFAULT_HOST) + ":" + (port || DEFAULT_PORT) + endpoint;
}

/**
 * Get player status (one-time request)
 * @param {string} host - API host
 * @param {number} port - API port
 * @param {string} filter - Comma-separated fields to return
 * @returns {string} - URL for XMLHttpRequest
 */
function getStatusUrl(host, port, filter) {
    let url = buildUrl(host, port, "/status");
    if (filter) {
        url += "?filter=" + encodeURIComponent(filter);
    }
    return url;
}

/**
 * Get current LRC lyrics
 * @param {string} host - API host
 * @param {number} port - API port
 * @returns {string} - URL for XMLHttpRequest
 */
function getLyricUrl(host, port) {
    return buildUrl(host, port, "/lyric");
}

/**
 * Get all types of lyrics (lyric, tlyric, rlyric, lxlyric)
 * @param {string} host - API host
 * @param {number} port - API port
 * @returns {string} - URL for XMLHttpRequest
 */
function getLyricAllUrl(host, port) {
    return buildUrl(host, port, "/lyric-all");
}

/**
 * Get SSE subscription URL for real-time updates
 * @param {string} host - API host
 * @param {number} port - API port
 * @param {string} filter - Comma-separated fields to subscribe
 * @returns {string} - URL for EventSource/SSE
 */
function getSubscribeUrl(host, port, filter) {
    let url = buildUrl(host, port, "/subscribe-player-status");
    if (filter) {
        url += "?filter=" + encodeURIComponent(filter);
    }
    return url;
}

/**
 * Player control URLs
 */
function getControlUrl(host, port, action, params) {
    let url = buildUrl(host, port, "/" + action);
    if (params) {
        const queryString = Object.keys(params)
            .map(key => encodeURIComponent(key) + "=" + encodeURIComponent(params[key]))
            .join("&");
        if (queryString) {
            url += "?" + queryString;
        }
    }
    return url;
}

/**
 * Parse SSE data line
 * SSE format: 
 *   event: eventName
 *   data: "value"
 */
function parseSSELine(line) {
    if (line.startsWith("event: ")) {
        return { type: "event", value: line.substring(7).trim() };
    } else if (line.startsWith("data: ")) {
        let value = line.substring(6).trim();
        // Remove quotes if present
        if (value.startsWith('"') && value.endsWith('"')) {
            value = value.slice(1, -1);
        }
        // Try to parse as JSON if it looks like JSON
        if (value.startsWith('{') || value.startsWith('[')) {
            try {
                value = JSON.parse(value);
            } catch (e) {
                // Keep as string
            }
        }
        return { type: "data", value: value };
    }
    return null;
}

/**
 * Parse complete SSE response into events
 * @param {string} text - Raw SSE text
 * @returns {Array} - Array of {event, data} objects
 */
function parseSSEResponse(text) {
    const lines = text.split('\n');
    const events = [];
    let currentEvent = null;
    
    for (const line of lines) {
        const parsed = parseSSELine(line);
        if (!parsed) continue;
        
        if (parsed.type === "event") {
            currentEvent = parsed.value;
        } else if (parsed.type === "data" && currentEvent) {
            events.push({
                event: currentEvent,
                data: parsed.value
            });
            currentEvent = null;
        }
    }
    
    return events;
}

/**
 * Status values
 */
const PlayerStatus = {
    PLAYING: "playing",
    PAUSED: "paused",
    STOPPED: "stoped",  // Note: LX Music uses "stoped" (typo in API)
    ERROR: "error"
};

/**
 * Default filter for SSE subscription
 * Includes all lyrics-related fields
 */
const DEFAULT_SUBSCRIBE_FILTER = "status,name,singer,albumName,lyricLineText,lyricLineAllText,duration,progress,picUrl";

/**
 * Full filter including all lyric types
 */
const FULL_SUBSCRIBE_FILTER = "status,name,singer,albumName,lyricLineText,lyricLineAllText,lyric,tlyric,rlyric,duration,progress,picUrl";
