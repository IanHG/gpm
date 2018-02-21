local path = assert(require "lib.path")
local util = assert(require "lib.util")

local M = {}

-- Database with entries e.g.:
-- gpk: gcc, pkv: 6.3.0, prereq: ...
local db = nil

--- Create db entry from string (read from file).
--
-- @param line    The line to create db_entry from.
--
-- @return   Returns the creat db_entry table.
local function create_db_entry(line)
   local db_entry = {}
   local sline = util.split(line, ";")
   for _, field in pairs(sline) do
      sfield = util.split(field, ":")
      db_entry[util.trim(sfield[1])] = util.trim(sfield[2])
   end
   return db_entry
end

--- Create database entry
--
-- @param package  The package.
--
-- @return   Return database entry for package
local function create_package_db_entry(package)
   return { 
       gpk    = util.conditional(package.definition.pkgname, package.definition.pkgname, "nil"), 
       pkv    = util.conditional(package.definition.pkgversion, package.definition.pkgversion, "nil"), 
       prereq = util.conditional(package.prereq, package.prereq, "nil"),
   }
end

--- Check if two db_entries are the same
--
-- @param entry1  First entry.
-- @param entry2  Second entry.
--
-- @return   Returns true if the two entries are the same, otherwise false.
local function is_same_package_db_entry(entry1, entry2)
   if entry1["gpk"] == entry2["gpk"] and
      entry1["pkv"] == entry2["pkv"] then

      if not entry1["prereq"] or not entry2["prereq"] then
         return true
      elseif entry1["prereq"] == entry2["prereq"] then
         return true
      end 
   end
   
   -- If we get here the two entries are not the same
   return false
end

--- Get path of database file
-- 
-- @param config    The config.
--
-- @return   Returns path of db file.
local function get_db_path(config)
   local db_path = ""
   if config.db.path then
      if path.is_abs_path(config.db.path) then
         db_path = config.db.path
      else
         db_path = config.stack_path .. "/" .. config.db.path
      end
   else
      db_path = config.stack_path .. "/db"
   end
   return db_path
end

--- Use the database?
--
-- @return     Returns whether to use the database or not.
local function use_db()
   if db then
      return true
   else
      return false
   end
end

--- Load the database to memory
--
-- @param config   The config.
local function load_db(config)
   if not config.db then
      return
   end

   db = {}
   
   -- Open db file
   local db_path = get_db_path(config)
   local db_file = io.open(db_path, "r")

   if db_file then
      -- Read and parse lines:
      -- gpk: gcc; pkv: 6.3.0; prereq: nil
      for line in db_file:lines() do
         -- Create db entry for line
         local db_entry = create_db_entry(line)

         -- Insert entry into db
         table.insert(db, #db + 1, db_entry)
      end
   end
end

--- Save the database to disk
--
-- @param config   The config.
local function save_db(config)
   if not config.db then
      return
   end

   local db_path = get_db_path(config)
   local db_file = io.open(db_path, "w")

   for _, db_entry in pairs(db) do
      db_file:write("gpk: " .. db_entry["gpk"] .. "; pkv: " .. db_entry["pkv"] .. "; prereq: " .. db_entry["prereq"] .. "\n")
   end
end

--- Insert an element into the database.
--
-- @param package   The package to insert.
local function insert_element(package)
   if not db then
      return
   end

   table.insert(db, #db + 1, create_package_db_entry(package))
end

--- Remove an element from the database.
--
-- @param package    The package to remove.
local function remove_element(package)
   if not db then
      return
   end

   local package_entry = create_package_db_entry(package)

   local i = 1
   while i <= #db do
      if is_same_package_db_entry(db[i], package_entry) then
         table.remove(db, i)
      else
         i = i + 1
      end
   end
end

--- Check if a package is already installed
-- 
-- @param package   The package to check for.
--
-- @return   Returns true if already installed, otherwise false.
local function installed(package)
   if not db then
      return false
   end

   -- Create database entry to look for
   local package_entry = create_package_db_entry(package)
   
   -- Look for package in db
   for _, db_entry in pairs(db) do
      if is_same_package_db_entry(db_entry, package_entry) then
         return true
      end
   end

   -- If we reach here the package was not found
   return false
end

--- List all installed packages
local function list_installed()
   for n, db_entry in pairs(db) do
      util.print(db_entry, n)
   end
end

-- Load module
M.use_db         = use_db
M.load_db        = load_db
M.save_db        = save_db
M.insert_element = insert_element
M.remove_element = remove_element
M.installed      = installed
M.list_installed = list_installed

return M
