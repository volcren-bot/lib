--!strict
local RecommendSurvey = require("../main/interfaces/chatbox/recommend_survey")

local open = RecommendSurvey.is_open()
if not open then
	print("the survey isn't open")
else
	print("skipping the survey:", RecommendSurvey.skip())
end
