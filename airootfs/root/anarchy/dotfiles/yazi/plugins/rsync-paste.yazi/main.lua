local prepare_rsync = ya.sync(function()
	local yanked = cx.yanked

	local operation = {
		urls = {},
		target_dir = tostring(cx.active.current.cwd),
		is_cut_operation = yanked.is_cut,
	}

	if #yanked == 0 then
		return operation
	end

	for _, url in pairs(yanked) do
		table.insert(operation.urls, tostring(url))
	end

	return operation
end)

return {
	entry = function()
		local rsync_operation = prepare_rsync()

		if #rsync_operation.urls == 0 then
			ya.notify({
				title = 'rsync-paste',
				content = 'No files to move/copy',
				timeout = 5,
				level = 'warn',
			})
			return
		end

		local action = rsync_operation.is_cut_operation and 'Moving' or 'Copying'

		local cmd = 'rsync -a --info=progress2 --fsync'

		if rsync_operation.is_cut_operation then
			cmd = cmd .. ' --remove-source-files'
		end

		for _, u in ipairs(rsync_operation.urls) do
			cmd = cmd .. ' ' .. ya.quote(u)
		end
		cmd = cmd .. ' ' .. ya.quote(rsync_operation.target_dir)

		local permit = ui.hide()

		local status, err = Command('sh')
			:arg({ '-c', cmd })
			:stdin(Command.INHERIT)
			:stdout(Command.INHERIT)
			:stderr(Command.INHERIT)
			:status()

		permit:drop()

		if not status or not status.success then
			ya.notify({
				title = 'rsync-paste',
				content = string.format('%s failed: %s', action, tostring(err or status and status.code or 'unknown')),
				timeout = 10,
				level = 'error',
			})
			return
		end

		if rsync_operation.is_cut_operation then
			for _, url in ipairs(rsync_operation.urls) do
				Command('rm')
					:arg({ '-rf', tostring(url) })
					:status()
			end
		end

		ya.notify({
			title = 'rsync-paste',
			content = string.format('%s %d files done', action, #rsync_operation.urls),
			timeout = 5,
			level = 'info',
		})
	end,
}
