local path     = assert(require "lib.path")
local util     = assert(require "lib.util")
local logging  = assert(require "lib.logging")
local packages = assert(require "lib.packages")

local M = {}

-- Database with entries e.g.:
-- gpk: gcc, pkv: 6.3.0, prereq: ...
local db = nil

--- Create db entry from string (read from file).
--
-- Will take a line with the following form:
--    <key1:value1;key2:value2;...>
-- and create a db_entry table from it.
--
-- @param line    The line to create db_entry from.
--
-- @return   Returns the creat db_entry table.
local function create_db_entry(line)
   local db_entry = {}
   line = string.match(line, "<(.-)>")
   local sline = util.split(line, ";")
   for _, field in pairs(sline) do
      sfield = util.split(field, ":")
      local sfield2_trimmed = util.trim(sfield[2])
      db_entry[util.trim(sfield[1])] = util.conditional(sfield2_trimmed == "nil", nil, sfield2_trimmed)
   end
   return db_entry
end

--- Create db line from db_entry.
--
-- From db_entry table will create a line with the following format:
--    <key1:value1;key2:value2;...>
--
-- @param db_entry   The entry to create line for.
--
-- @return   Returns the created line.
local function create_db_line(db_entry)
   -- Create the line
   local line = "<"
   local first = true
   for key, value in pairs(db_entry) do
      if not first then
         line = line .. ";"
      end
      if value then
         line = line .. key .. ":" .. value
      else
         line = line .. key .. ":nil"
      end
      first = false
   end
   line = line .. ">\n"
   
   -- Return
   return line
end

--- Create database entry
--
-- @param package  The package.
--
-- @return   Return database entry for package
local function create_package_db_entry(package)
   return { 
       gpk    = util.conditional(package.definition.pkgname   , package.definition.pkgname           , "nil"), 
       pkv    = util.conditional(package.definition.pkgversion, package.definition.pkgversion        , "nil"), 
       prereq = util.conditional(package.prerequisite         , packages.prerequisite_string(package), "nil"),
   }
end

--- Check if two db entries are the same
--
-- @param entry1  First entry.
-- @param entry2  Second entry.
--
-- @return   Returns true if the two entries are the same, otherwise false.
local function is_same_db_entry(entry1, entry2)
   return util.deepcompare(entry1, entry2)
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
local function get_db_path(config, subdb)
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
   
   db_path = db_path .. "." .. subdb

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
local function load_db(config, sub_db_paths)
   if not config.db then
      return
   end
   
   -- Set default db files to load
   if not sub_db_paths then
      sub_db_paths = {"package", "childstack"}
   end

   db = {}
   
   -- Loop over sub databases
   for _, subdb in pairs(sub_db_paths) do
      if not db[subdb] then
         db[subdb] = {}
      end

      -- Open db file
      local db_path = get_db_path(config, subdb)
      local db_file = io.open(db_path, "r")

      if db_file then
         -- Read and parse lines:
         -- e.g. <gpk: gcc; pkv: 6.3.0; prereq: nil>
         for line in db_file:lines() do
            -- Create db entry for line
            local db_entry = create_db_entry(line)

            -- Insert entry into db
            table.insert(db[subdb], #db[subdb] + 1, db_entry)
         end
      end
   end
end

--- Save the database to disk
--
-- @param config   The config.
local function save_db(config, sub_db_paths)
   if (not config.db) or (not db) then
      return
   end
   
   if not sub_dp_paths then
      sub_db_paths = {"package", "childstack"}
   end
   
   for _, subdb in pairs(sub_db_paths) do
      -- Open db file for writing
      local db_path = get_db_path(config, subdb)
      local db_file = io.open(db_path, "w")
      
      -- Write entries to file
      for _, db_entry in pairs(db[subdb]) do
         db_file:write(create_db_line(db_entry))
      end
   end
end

--- Insert an element into the database.
--
-- @param subdb     The sub-database to insert into, e.g. "package".
-- @param db_entry  The entry to insert.
local function insert_entry(subdb, db_entry)
   if not db then
      return
   end

   table.insert(db[subdb], #db[subdb] + 1, db_entry)
end

--- Remove an element from the database if it exists.
--
-- @param subdb     The sub-database to remove from, e.g. "package".
-- @param db_entry  The entry to remove if found.
local function remove_entry(subdb, db_entry)
   if not db then
      return
   end

   local i = 1
   while i <= #db[subdb] do
      if is_same_db_entry(db[subdb][i], db_entry) then
         table.remove(db[subdb], i)
      else
         i = i + 1
      end
   end
end

--- Insert a package into the database.
--
-- @param package   The package to insert.
local function insert_package(package)
   -- Create database entry to look for
   local package_entry = create_package_db_entry(package)
   
   -- Insert
   insert_entry("package", package_entry)
end

---  Remove a package from the database.
--
-- @param package    The package to remove.
local function remove_package(package)
   -- Create database entry to look for
   local package_entry = create_package_db_entry(package)
   
   -- Insert
   remove_entry("package", package_entry)
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
   for _, db_entry in pairs(db["package"]) do
      if is_same_package_db_entry(db_entry, package_entry) then
         return true
      end
   end

   -- If we reach here the package was not found
   return false
end

--- List all installed packages
local function list_installed()
   for n, db_entry in pairs(db["package"]) do
      logging.message(util.print(db_entry, n), io.stdout)
   end
end

-- Load module
M.use_db         = use_db
M.load_db        = load_db
M.save_db        = save_db
M.insert_package = insert_package
M.remove_package = remove_package
M.installed      = installed
M.list_installed = list_installed

return M
