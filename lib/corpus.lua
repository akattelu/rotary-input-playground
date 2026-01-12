local Corpus = {}

-- Fallback word list if words.txt is not available
local FALLBACK_WORDS = {
  "the", "be", "to", "of", "and", "a", "in", "that", "have", "it",
  "for", "not", "on", "with", "he", "as", "you", "do", "at", "this",
  "but", "his", "by", "from", "they", "we", "say", "her", "she", "or",
  "an", "will", "my", "one", "all", "would", "there", "their", "what",
  "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
  "function", "return", "const", "let", "var", "string", "number",
  "select", "filter", "search", "find", "start", "stop", "send",
  "think", "thank", "throw", "through", "then", "than", "ten", "ton",
  "token", "taken", "turn", "twin", "tension", "transition", "train"
}

-- Load words from file or use fallback
function Corpus.load(filename)
  local words = {}

  filename = filename or "words.txt"
  local content = love.filesystem.read(filename)

  if content then
    for word in content:gmatch("[^\r\n]+") do
      if #word > 0 then
        table.insert(words, word:lower())
      end
    end
    print("Loaded " .. #words .. " words from " .. filename)
  else
    words = FALLBACK_WORDS
    print("Using fallback word list (" .. #words .. " words)")
  end

  return words
end

return Corpus
