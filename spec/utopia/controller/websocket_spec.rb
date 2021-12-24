#!/usr/bin/env rspec
# frozen_string_literal: true

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'rack/test'
require 'utopia/controller'

require 'async/websocket/client'
require 'async/websocket/adapters/rack'

require 'falcon/server'
require 'falcon/adapters/rack'

require 'async/http/client'
require 'async/http/endpoint'

RSpec.describe Utopia::Controller do
	context Async::WebSocket::Client do
		include Rack::Test::Methods
		include_context Async::RSpec::Reactor
		
		let(:app) {Rack::Builder.parse_file(File.expand_path('websocket_spec.ru', __dir__)).first}
		
		before do
			@endpoint = Async::HTTP::Endpoint.parse("http://localhost:7050/server/events")
			@server = Falcon::Server.new(Falcon::Server.middleware(app), @endpoint)
			
			@server_task = reactor.async do
				@server.run
			end
		end
		
		let(:client) {Async::HTTP::Client.new(@endpoint)}
		
		after do
			@server_task.stop
		end
		
		it "fails for normal requests" do
			get "/server/events"
			
			expect(last_response.status).to be == 400
		end
		
		it "can connect to websocket" do
			Async::WebSocket::Client.connect(@endpoint) do |connection|
				expect(connection.read).to be == {type: "test", data: "Hello World"}
			end
		end
	end
end
