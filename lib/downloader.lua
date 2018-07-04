local M = {}

--- Load libraries
local class      = assert(require "lib.class")
local util       = assert(require "lib.util")
local settings   = assert(require "lib.settings")
local filesystem = assert(require "lib.filesystem")

--- Determine the type of url ("git", "http", or "local")
local function determine_url_type(url)
   local function is_git(url)
      return url:match("git$")
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
   self.signature   = ""
   self.url_type    = nil -- "git", "http", or "local"
   self.destination = ""
   
   -- Some settings 
   self.http_method = "wget"
   self.force       = false
end

--- Create command for downloading using git
function downloader_class:git_download_command()
   return "git clone --recursive " .. self.url .. " " .. self.destination
end

--- Create command for downloading with http
function downloader_class:http_download_command()
   if self.http_method == "wget" then
      return "wget --progress=dot -O " .. self.destination .. " " .. self.url
   elseif self.http_method == "curl" then
      -- not implemented yet
      print("curl download not implemented yet")
      assert(false)
   else
      print("Unknown http_donwload method")
      assert(false)
   end
end

--- Create command for local copying
function downloader_class:local_download_command()
   return "cp " .. self.url .. " " .. self.destination
end

--- Download url
function downloader_class:download(url, dest)
   self.url         = url
   self.url_type    = determine_url_type(self.url)
   self.destination = dest

   -- If file exist, we remove if forced, else return
   if filesystem.exists(self.destination) then
      if self.force then         
         filesystem.remove(self.destination)
      else
         return
      end
   end
   
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
   local status = util.execute_command(cmd)

   if status ~= 0 then
      assert(false)
   end
end

---
M = downloader_class:create()

---
return M
