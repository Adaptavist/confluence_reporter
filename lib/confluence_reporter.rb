# Copyright 2015 Adaptavist.com Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "confluence_reporter/version"
require "base64"
require 'uri'
require 'net/http'
require 'net/https'
require 'json'

module ConfluenceReporter
    
    class Reporter
    
    attr_accessor :body_message, :base_url, :user, :password

        def initialize(base_url, user, password)
            @body_message = "<h2>#{Time.now}</h2>"
            @base_url = base_url
            @user = user
            @password = password
        end

        %w(debug info warn error fatal).each do |m|
            define_method(m) do |*args|
                log(*args)
            end
        end

        def log(message, print=true)
            if print
                puts message
            end
            @body_message = @body_message + "<p>#{message.gsub("\\n", "<br/>").gsub("<", "&lt;").gsub(">","&gt;").gsub("&", "&amp;")}</p>"
        end

        def log_structured_code(message, print=true)
            if print
                puts message
            end
            message.split("\n").each do |line|
                    @body_message = @body_message + "<pre>#{line}</pre>"
            end
        end

        def find_page_by_name(name, parrent_page_id=nil)
            found = nil
            if parrent_page_id
                uri = URI.parse(@base_url + parrent_page_id + "/child/page")
                https = Net::HTTP.new(uri.host, uri.port)
                https.use_ssl = true
                
                # https.set_debug_output $stderr
                next_url = uri.request_uri
                # Confluence limits the result to only 25
                while (next_url and !found)
                    request = Net::HTTP::Get.new(next_url)
                    request.basic_auth(@user, @password)
                    request['Accept'] = 'application/json'
                    response = https.request(request)
                    resp = JSON.parse(response.body)
                    resp["results"].each do |res|
                        if res["title"] == name
                            found = res
                            break
                        end
                    end

                    if resp["_links"]["next"]
                        if next_url == (resp["_links"]["base"] + resp["_links"]["next"])
                            next_url = nil
                        else
                            next_url = resp["_links"]["base"] + resp["_links"]["next"]
                        end
                    else
                        next_url = nil
                    end
                end
            else
                uri = URI.parse(@base_url)
                params={"start" => "0", "limit" => "40", "title" => name, "type" => "page", "expand" => "id,version,ancestors"}
                uri.query = URI.encode_www_form(params)
                https = Net::HTTP.new(uri.host, uri.port)
                https.use_ssl = true
                
                request = Net::HTTP::Get.new(uri.request_uri)
                request.basic_auth(@user, @password)
                request['Accept'] = 'application/json'

                response = https.request(request)
                resp = JSON.parse(response.body)
                found = resp["results"]
            end
            found
        end

        def find_page_by_id(page_id)
            uri = URI.parse(@base_url + page_id)
            params={"expand" => "body,body.storage,version"}
            uri.query = URI.encode_www_form(params)
            https = Net::HTTP.new(uri.host, uri.port)
            https.use_ssl = true

            request = Net::HTTP::Get.new(uri.request_uri)
            request.basic_auth(@user, @password)
            request['Accept'] = 'application/json'

            response = https.request(request)
            JSON.parse(response.body)
        end

        # appends the log to confluence page if found, if not creates new page
        # clears the log
        def report_event(name, parrent_page_id=nil, space=nil)
            page = find_page_by_name(name, parrent_page_id)
            if page
                append_to_page(page["id"], parrent_page_id)
            else
                create_page(name, space, parrent_page_id)
            end
            clear_log
        end

        # Creates new page with title set, 
        # if parrent_page_id is provided it adjusts ancestor accordingly and 
        # the same space short key  
        def create_page(title, space, parrent_page_id=nil)
            params = { 'type' => 'page',
                'title' => title,
                'space' => {'key' => space},
                'body' => {
                    'storage' => {
                        'value' => ("#{ @body_message.to_json.gsub("&&", "&amp;&amp;").gsub(/\\u001b.../, "   ") }").force_encoding('UTF-8'),
                        'representation' => 'storage'
                        }
                    }
                }
            if parrent_page_id
                params['ancestors'] = [{'type' => 'page', 'id' => parrent_page_id}]
            end

            uri = URI.parse(@base_url)
            https = Net::HTTP.new(uri.host,uri.port)
            https.use_ssl = true
            # https.set_debug_output $stderr
            req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
            req.basic_auth(@user, @password)
            req['Accept'] = 'application/json'
            req.body = "#{params.to_json}"
            response = https.request(req)
            response = JSON.parse(response.body)
            if response["statusCode"] == 400
                puts response.inspect
                puts req.body.inspect
                puts "Create page: Error reporting to confluence: #{response["message"]}"
                raise "Create page: Error reporting to confluence: #{response["message"]}"
            else
                puts "Reported page creation."
            end
        end

        def append_to_page(page_id, parrent_page_id)
            page = find_page_by_id(page_id)
            page["version"]["number"] = page["version"]["number"].to_i + 1
            page["body"]["storage"]["value"] = (page["body"]["storage"]["value"] + "#{ @body_message.to_json.gsub(/\\u001b.../, "   ") }").force_encoding('UTF-8')
            page['ancestors'] = [{'type' => 'page', 'id' => parrent_page_id}]
            uri = URI.parse(@base_url + "#{page_id}")
            https = Net::HTTP.new(uri.host,uri.port)
            https.use_ssl = true
            # https.set_debug_output $stderr
            req = Net::HTTP::Put.new(uri.path, initheader = {'Content-Type' =>'application/json'})
            req.basic_auth(@user, @password)
            req['Accept'] = 'application/json'
            req.body = "#{page.to_json}"
            response = https.request(req)
            response = JSON.parse(response.body)
            if response["statusCode"] == 400
                puts response.inspect
                puts req.body.inspect
                puts "Append to page: Error reporting to confluence: #{response["message"]}"
                raise "Append to page: Error reporting to confluence: #{response["message"]}"
            else
                puts "Reported page update."
            end
        end

        def clear_log
            @body_message = ""
        end
    end
end