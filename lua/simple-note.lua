---@class Config
---@field notes_dir string path to the directory where the notes should be created
---@field journal_template_path string path to the daily journal template
local config = {
  notes_dir = "~/notes/",
  telescope_new = "<C-n>",
  telescope_delete = "<C-x>",
  telescope_rename = "<C-r>",
  journal_template_path = "/journal_template.txt",
}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args table
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  local dir = tostring(vim.fn.expand(M.config.notes_dir))

  if not vim.loop.fs_stat(dir) then
    vim.loop.fs_mkdir(dir, 511) -- 511 (0777 in octal) means the owner, group and others can read, write and execute.
    vim.notify("Created " .. dir)
  end
end

M.searchNotes = function()
  require("telescope.builtin").live_grep({
    prompt_title = "Search Notes (" .. M.config.notes_dir .. ")",
    cwd = M.config.notes_dir,
    disable_coordinates = true,
  })
end

M.listNotes = function()
  local actions = require("telescope.actions")
  local actions_state = require("telescope.actions.state")
  -- local finders = require("telescope.finders")
  local find_command = { "find", ".", "-maxdepth", "2", "-not", "-type", "d" }

  M.picker = require("telescope.builtin").find_files({
    cwd = M.config.notes_dir,
    find_command = find_command,
    layout_strategy = "flex",
    prompt_title = "Find Notes (" .. M.config.notes_dir .. ")",
    results_title = "Notes",
    attach_mappings = function(_, map)
      map({ "i", "n" }, M.config.telescope_new, function(prompt_bufnr)
        local current_line = actions_state.get_current_line()
        local opts = current_line ~= "" and { fargs = { current_line } } or {}
        M.createNoteFile(opts)
        local picker = actions_state.get_current_picker(prompt_bufnr)
        actions.close(prompt_bufnr) -- Close the previewer
        M.listNotes()
      end)
      map({ "i", "n" }, M.config.telescope_delete, function(prompt_bufnr)
        local entry = actions_state.get_selected_entry(prompt_bufnr)
        local filePath = vim.fn.expand(M.config.notes_dir) .. entry.value
        local picker = actions_state.get_current_picker(prompt_bufnr)
        local confirm = vim.fn.confirm("Are you sure you want to delete " .. filePath .. "?", "&Yes\n&No")

        if confirm == 1 then
          os.remove(filePath)
          vim.notify(filePath .. " has been deleted")
          actions.close(prompt_bufnr) -- Close the previewer
          M.listNotes()
        end
      end)
      map({ "i", "n" }, M.config.telescope_rename, function(prompt_bufnr)
        local entry = actions_state.get_selected_entry(prompt_bufnr)
        local oldFilePath = vim.fn.expand(M.config.notes_dir) .. entry.value
        local newFileName = vim.fn.input("Enter new filename: ", entry.value)
        local newFilePath = vim.fn.expand(M.config.notes_dir) .. newFileName
        local picker = actions_state.get_current_picker(prompt_bufnr)
        os.rename(oldFilePath, newFilePath)
        vim.notify(oldFilePath .. " has been renamed to " .. newFilePath)
        actions.close(prompt_bufnr) -- Close the previewer
        M.listNotes()
      end)
      return true
    end,
  })
end

---@param opts table
M.createAndOpenNoteFile = function(opts)
  local full_path = M.createNoteFile(opts)

  if full_path == nil then
    return
  end

  vim.cmd("edit " .. full_path)
end

M.createAndOpenJournalFile = function(opts)
  local full_path = M.createJournalFile(opts)

  if full_path == nil then
    return
  end

  vim.cmd("edit " .. full_path)
end

---@return string|nil full_path
M.createJournalFile = function()
  local notes_path = vim.fn.expand(M.config.notes_dir)
  local full_path = notes_path
  local current_date = os.date("%Y-%m-%d") -- Get the current date
  full_path = full_path .. "journal/" .. current_date .. ".md"

  if vim.fn.filereadable(full_path) == 1 then
    return full_path
  end

  local template_path = vim.fn.stdpath("config") .. M.config.journal_template_path
  local template_lines = vim.fn.readfile(template_path)
  local template_content = table.concat(template_lines, "\n")

  local result = string.gsub(template_content, "%{{%w+}}", function(placeholder)
    local variable_name = placeholder:sub(3, -3) -- Extract variable name from {{placeholder}}
    if variable_name == "date" then
      return os.date("%a %d %b %Y")
    else
      return placeholder -- Return the placeholder if variable is not recognized
    end
  end)

  local file = io.open(full_path, "w")
  if file then
    file:write(result)
    file:close()
  else
    vim.notify("Unable to create file " .. full_path)
  end

  return full_path
end

---@param opts table
---@return string|nil full_path
M.createNoteFile = function(opts)
  local notes_path = vim.fn.expand(M.config.notes_dir)
  local full_path = notes_path

  if opts ~= nil and opts.fargs ~= nil and opts.fargs[1] then
    local filename = opts.fargs[1]
    -- Check if filename has an extension
    if filename:match("%.([^%.]+)$") then
      full_path = full_path .. filename
    else
      full_path = full_path .. filename .. ".md"
    end
  else
    full_path = full_path .. os.date("%A_%B_%d_%Y_%I_%M_%S_%p") .. ".md"
  end

  if vim.fn.filereadable(full_path) == 1 then
    return full_path
  end

  local file = io.open(full_path, "a")

  if file == nil then
    vim.notify("Unable to create file " .. full_path)
    return nil
  end

  vim.notify(full_path .. " has been created")

  file:close()
  return full_path
end

return M
