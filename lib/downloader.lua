local M = {}

--- Load libraries
local luautil    = assert(require "lib.luautil")
local class      = assert(require "lib.class")
local util       = assert(require "lib.util")
local filesystem = assert(require "lib.filesystem")
local logging    = assert(require "lib.logging")
local logger     = logging.logger
local http       = luautil.require("socket.http")

--- Determine the type of url ("git", "http", or "local")
local function determine_url_type(url)
   local function is_git(url)
      return   (  url:match("git$")
               )
   end

   local function is_http(url)
      return   (  url:match("http://") 
               or url:match("https://") 
               or url:match("ftp://") 
               )
   end

   if is_git(url) then
      return "git"
   elseif is_http(url) then
      return "http"
   else
      return "local"
   end
end

--- Downloader class: Handles downloading of files (or copying of local source).
local downloader_class = class.create_class()

function downloader_class:__init()
   -- Source and destination
   self.url         = ""
   self.url_type    = nil -- "git", "http", or "local"
   self.destination = ""
   
   -- Signature
   self.url_signature = ""

   -- Some internal settings 
   --self.has_luasocket_http   = http and true or false
   self.has_luasocket_http   = false
   self.external_http_method = "wget"
end

--- Internal function to clean-up if download failed.
--    
--    Will remove anything that was downloaded.
function downloader_class:__cleanup_on_fail()
   if filesystem.exists(self.destination) then
      filesystem.remove(self.destination)
   end
   
   ---- Do something else here...
   --if filesystem.exists(self.signature) then
   --   filesystem.remove(self.signature)
   --end
end

--- Create command for downloading using git
function downloader_class:git_download_command()
   return "git clone --recursive " .. self.url .. " " .. self.destination
end

--- Create command for downloading with http
function downloader_class:http_download_command()
   if self.external_http_method == "wget" then
      return "wget --progress=dot -O " .. self.destination .. " " .. self.url
   elseif self.external_http_method == "curl" then
      -- not implemented yet
      print("curl download not implemented yet")
      assert(false)
   else
      print("Unknown http_download method")
      assert(false)
   end
end

--- Create command for local copying
function downloader_class:local_download_command()
   return "cp " .. self.url .. " " .. self.destination
end

--- Use LuaSocket to download file, instead of external program
function downloader_class:download_internal()
   local body, code = http.request(self.url)
   
   if not body then 
      error(code) 
   end
   
   -- save the content to a file
   local f = assert(io.open(self.destination, 'wb')) -- open in "binary" mode
   f:write(body)
   f:close()

   return true
end

--- Use external program to download file
function downloader_class:download_external()
   -- Create "download" command
   local cmd = nil

   if self.url_type == "git" then
      cmd = self:git_download_command()
   elseif self.url_type == "http" then
      cmd = self:http_download_command()
   elseif self.url_type == "local" then
      cmd = self:local_download_command()
   else
      assert(false)
   end

   if util.isempty(cmd) then
      assert(false)
   end
   
   -- Execute command
   local  status = util.execute_command(cmd, false)
   
   return status
end

--- Download url
function downloader_class:download(url, dest, force, hardfail)
   if util.isempty(url) or util.isempty(dest) then
      logger:alert("URL or destination is empty.")
      return false
   end

   logger:message("Downloading : '" .. url .. "' to destination '" .. dest .. "'.")

   self.url         = url
   self.url_type    = determine_url_type(self.url)
   self.destination = dest

   -- If file exist, we remove if forced, else return
   if filesystem.exists(self.destination) then
      if force then
         logger:message("Removing destination.")
         if filesystem.isdir(self.destination) then
            filesystem.rmdir(self.destination, true)
         else
            filesystem.remove(self.destination)
         end
      else
         logger:message("Destination already exists, skipping download. If you want to download anyways, re-run with '--force-download'.")
         return true
      end
   end
   
   -- 
   local status = nil
   if self.url_type == "git" then
      status = self:download_external()
   else
      if self.has_luasocket_http then
         status = self:download_internal()
      else
         status = self:download_external()
      end
   end
   
   if (not status) and hardfail then
      logger:alert("Downloader could not download file '" .. self.url .. "'.")
      assert(false)
   end

   return status
end

local function create()
   local  dl = downloader_class:create()
   return dl
end

---
M.create = create

---
return M
