local process = require '@lute/process'

local phrases = require './phrases'

local beatlinks, beatneedles = phrases.beatlinks, phrases.beatneedles

-- tutorials: the page (site/app/tutorials) lights a panel line for every [phrase](code:…) / [phrase](mark:…).
-- The build fails on prose outside a phrase, and on a phrase whose needle is on no panel
-- when it lights. TUTORIALS=1 lists what every phrase lights.
local PANEL_KINDS = { luau = 'script', output = 'out', state = 'ds', cloud = 'ds' }

local function checktutorial(file: string, md: string)
	local panels: { [string]: { code: string, kind: string } } = {}
	local order: { string } = {}
	local title = '(intro)'
	local beats: { { target: string, text: string } } = {}
	local frames: { { caption: string, kind: string, tag: number, code: string } } = {}

	local function finish()
		local where = `docs/tutorials/{file} "{title}"`
		for _, f in frames do
			if f.tag > #beats then
				error(`{where}: frame @{f.tag} of '{f.caption}', but the step has {#beats} phrases`, 0)
			end
			if not panels[f.caption] then
				panels[f.caption] = { code = '', kind = f.kind }
				table.insert(order, f.caption)
			end
		end

		for k, beat in beats do
			local shown = {}
			for _, caption in order do
				shown[caption] = panels[caption].code
			end
			for _, f in frames do
				if f.tag <= k then shown[f.caption] = f.code end
			end

			for _, needle in beatneedles(beat.target) do
				local hit
				-- scripts first, like the page
				for _, wantscript in { true, false } do
					for _, caption in order do
						if hit or (panels[caption].kind ~= 'ds') ~= wantscript then continue end
						for _, line in shown[caption]:split '\n' do
							if line:find(needle, 1, true) then
								hit = `{caption}: {line:gsub('^%s+', '')}`
								break
							end
						end
					end
				end
				if not hit then
					error(`{where}: phrase {k} "{beat.text}" points at "{needle}", which is on no panel then`, 0)
				end
				if process.env.TUTORIALS == '1' then print(`{file} | {title} | {k} {beat.text:sub(1, 48)} -> {hit}`) end
			end
		end

		for _, f in frames do
			panels[f.caption] = { code = f.code, kind = f.kind }
		end
		for i = #order, 1, -1 do
			local p = panels[order[i]]
			if p.code == '' or p.kind == 'out' then
				panels[order[i]] = nil
				table.remove(order, i)
			end
		end
		beats, frames = {}, {}
	end

	local lines = md:split '\n'
	local i = 1
	while i <= #lines do
		local line = lines[i]
		local where = `docs/tutorials/{file} "{title}"`
		local heading = line:match '^##%s+(.*)$'
		local lang, info = line:match '^```(%a*)[ \t]*(.*)$'

		if heading then
			finish()
			title = heading
		elseif lang then
			local kind = PANEL_KINDS[lang]
			if not kind then error(`{where}: a \`\`\`{lang} block can't be lit; use \`\`\`output or \`\`\`state`, 0) end

			local body = {}
			i += 1
			while lines[i] ~= '```' do
				if lines[i] == nil then error(`{where}: unclosed \`\`\`{lang} block`, 0) end
				table.insert(body, lines[i])
				i += 1
			end

			local caption, tag = info:match '^(.-)%s*@(%d+)$'
			caption = caption or info:match '^(.-)%s*$'
			if caption == '' and lang == 'cloud' then caption = 'DataStore' end
			table.insert(
				frames,
				{ caption = caption, kind = kind, tag = tonumber(tag) or #beats, code = table.concat(body, '\n') }
			)
		else
			local targets, rest = beatlinks(line, where)
			for _, target in targets do
				table.insert(beats, { target = target, text = line:match '%[(.-)%]%(' or line })
			end

			-- what is left once phrases, list markers and table bars are gone must hold no words
			local bare = rest:gsub('^%s*%d+%.%s', ''):gsub('[|*:%-]', '')
			if bare:find '%w' then error(`{where}: text outside a phrase: {bare:match '^%s*(.-)%s*$'}`, 0) end
		end
		i += 1
	end
	finish()
end

return {
	checktutorial = checktutorial,
}
