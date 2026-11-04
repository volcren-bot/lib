--!strict
-- Reads an open certer's quiz and prints the answer it would give. Answers nothing.
local Certer = require("@lib/main/interfaces/mainscreen/certer")

assert(Certer.is_open(), "open the quiz first: Talk-to on the event's NPC")
print("model", Certer.model(), "category", Certer.category())
for _, answer in ipairs(Certer.answers() or {}) do
	print(answer.letter, answer.text)
end
local answer = Certer.correct()
print("answer", answer and answer.letter)
-- To answer it and finish the chat: Certer.solve()
