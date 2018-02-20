local M = {}

-- Database with entries e.g.:
-- gpk: gcc, pkv: 6.3.0, prereq: ...
local db = {}

--- Get path of database file
-- 
-- @param config    The config.
--
-- @return   Returns path of db file.
local function get_db_path(config)
   local db_path = ""
   if config.db.path then
      db_path = config.db.path
   else
      db_path = config.stack_path .. "/db"
   end
   return db_path
end

--- Load the database to memory
--
-- @param config   The config.
local function load_db(config)
   if not config.db then
      return
   end

   local db_path = get_db_path(config)
   local db_file = io.open(dp_path, "r")

   -- Read and parse lines:
   -- gpk: gcc; pkv: 6.3.0; prereq: nil
   for line in db_file:lines() do
      print(line)
   end
   --assert(loadfile(db_path))()
   --db  = db_
   --db_ = nil
end

--- Save the database to disk
--
-- @param config   The config.
local function save_db(config)
   if not config.db then
      return
   end

   local db_path = get_db_path(config)
   local db_file = io.open(dp_path, "w")

   for _, db_entry in pairs(db) do
      dp_file:write("gpk: " .. db_entry["gpk"] .. "; pkv: " .. db_entry["pkv"] .. "; prereq: " .. db_entry["prereq"])
   end
end

--- Insert an element into the database.
--
-- @param package   The package to insert.
local function insert_element(package)
   db.insert({ {"gpk", package.gpk}, {"pkv", package.pkv}, {"prereq", package.prereq}})
end

--- 
local function remove_element(package)
end

---
local function is_installed(package)

   return false
end

--- 
local function list_installed()
end

-- Load module
M.load_db        = load_db
M.save_db        = save_db
M.insert_element = insert_element
M.remove_element = remove_element
M.is_installed   = is_installed
M.list_installed = list_installed

return M
