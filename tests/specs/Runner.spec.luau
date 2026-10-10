return {
	["eq passes on equal values"] = function(expect)
		expect.eq(1, 1)
	end,
	["eq fails on different values"] = function(expect)
		expect.errors(function()
			expect.eq(1, 2)
		end)
	end,
	["near tolerates small difference"] = function(expect)
		expect.near(1.0, 1.05, 0.1)
	end,
}
