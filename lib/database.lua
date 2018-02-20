local path = assert(require "lib.path")
local util = assert(require "lib.util")

local M = {}

-- Database with entries e.g.:
-- gpk: gcc, pkv: 6.3.0, prereq: ...
local db = {}

--- Create database entry
--
-- @param package  The package.
--
-- @return   Return database entry for package
local function create_db_entry(package)
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
local function is_same_db_entry(entry1, entry2)
   util.print(entry1, "entry1")
   util.print(entry2, "entry2")

   if entry1["gpk"] == entry2["gpk"] and
      entry1["pkv"] == entry2["pkv"] and
      entry1["prereq"] == entry2["prereq"] then
      
      return true
   end

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

--- Load the database to memory
--
-- @param config   The config.
local function load_db(config)
   if not config.db then
      return
   end

   local db_path = get_db_path(config)
   local db_file = io.open(db_path, "r")

   if db_file then
      -- Read and parse lines:
      -- gpk: gcc; pkv: 6.3.0; prereq: nil
      for line in db_file:lines() do
         print(line)
      end
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
   local db_file = io.open(db_path, "w")

   for _, db_entry in pairs(db) do
      db_file:write("gpk: " .. db_entry["gpk"] .. "; pkv: " .. db_entry["pkv"] .. "; prereq: " .. db_entry["prereq"] .. "\n")
   end
end

--- Insert an element into the database.
--
-- @param package   The package to insert.
local function insert_element(package)
   table.insert(db, #db + 1, create_db_entry(package))
end

--- 
local function remove_element(package)
end

--- Check if a package is already installed
-- 
-- @param package   The package to check for.
--
-- @return   Returns true if already installed, otherwise false.
local function installed(package)
   -- Create database entry to look for
   local package_entry = create_db_entry(package)
   print("HERE")
   -- Look for package in db
   for _, db_entry in pairs(db) do
      print ("WTF")
      if is_same_db_entry(db_entry, package_entry) then
         return true
      end
   end

   os.exit(0)
   
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
M.load_db        = load_db
M.save_db        = save_db
M.insert_element = insert_element
M.remove_element = remove_element
M.installed      = installed
M.list_installed = list_installed

return M
