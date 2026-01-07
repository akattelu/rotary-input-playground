local Filter = {}

-- Onset clusters (word beginnings) - mapped to 8 joystick directions
-- These are rough phonetic/orthographic groupings
Filter.onset_clusters = {
  [1] = { "s", "st", "str", "sc", "sk", "sl", "sm", "sn", "sp", "sw" }, -- up
  [2] = { "t", "th", "tr", "tw" },                                      -- up-right
  [3] = { "p", "pr", "pl", "b", "br", "bl" },                           -- right
  [4] = { "c", "ch", "cl", "cr", "k", "q" },                            -- down-right
  [5] = { "m", "n", "w", "wh" },                                        -- down
  [6] = { "f", "fl", "fr", "v" },                                       -- down-left
  [7] = { "r", "l", "h" },                                              -- left
  [8] = { "d", "dr", "g", "gr", "gl", "j" },                            -- up-left
}

Filter.onset_labels = { "S-", "T-", "P/B-", "C/K-", "M/N/W-", "F/V-", "R/L/H-", "D/G/J-" }

-- Coda clusters (word endings)
Filter.coda_clusters = {
  [1] = { "e", "ee", "ea", "ie", "y", "o", "oo", "oe", "ow", "i", "u", "ue", "ew", "a", "ay", "ey" }, -- up (vowels)
  [2] = { "t", "te", "ght", "nt", "st", "k", "ck", "ke", "nk", "p", "pe" },                           -- up-right (unvoiced stops)
  [3] = { "s", "es", "ss", "se", "ce", "x", "sh", "ch" },                                             -- right (sibilants)
  [4] = { "d", "de", "ed", "nd", "ld" },                                                              -- down-right (D sounds)
  [5] = { "n", "ne", "en", "in", "on", "an", "m", "me", "im", "um", "om" },                          -- down (nasals)
  [6] = { "r", "re", "er", "or", "ar", "ir", "ur" },                                                  -- down-left (R sounds)
  [7] = { "ng", "ing", "ong", "ang" },                                                                -- left (NG sounds)
  [8] = { "l", "le", "al", "el", "ly", "ful", "ll" },                                                 -- up-left (L sounds)
}

Filter.coda_labels = { "-Vowel", "-T/K/P", "-S/X", "-D", "-N/M", "-R", "-NG", "-L" }

-- Check if word starts with any pattern in cluster
local function matches_onset(word, cluster_idx)
  if not cluster_idx then return true end
  local patterns = Filter.onset_clusters[cluster_idx]
  if not patterns then return true end

  for _, pattern in ipairs(patterns) do
    if word:sub(1, #pattern) == pattern then
      return true
    end
  end
  return false
end

-- Check if word ends with any pattern in cluster
local function matches_coda(word, cluster_idx)
  if not cluster_idx then return true end
  local patterns = Filter.coda_clusters[cluster_idx]
  if not patterns then return true end

  for _, pattern in ipairs(patterns) do
    if word:sub(- #pattern) == pattern then
      return true
    end
  end
  return false
end

-- Apply both filters
function Filter.apply(words, left_cluster, right_cluster)
  -- No filtering if both sticks centered
  if not left_cluster and not right_cluster then
    -- Return most frequent words
    local result = {}
    for i = 1, math.min(100, #words) do
      table.insert(result, words[i])
    end
    return result
  end

  local result = {}
  for _, word in ipairs(words) do
    if matches_onset(word, left_cluster) and matches_coda(word, right_cluster) then
      table.insert(result, word)
    end
    -- Limit for performance
    if #result >= 500 then break end
  end
  return result
end

return Filter
