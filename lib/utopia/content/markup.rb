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

require 'trenni/parsers'
require 'trenni/entities'
require 'trenni/strings'

require_relative 'tag'

module Utopia
	class Content
		class SymbolicHash < Hash
			def [] key
				raise KeyError.new("attribute #{key} is a string, prefer a symbol") if key.is_a? String
				super key.to_sym
			end
			
			def []= key, value
				super key.to_sym, value
			end
			
			def fetch(key, *args, &block)
				key = key.to_sym
				
				super
			end
			
			def include? key
				key = key.to_sym
				
				super
			end
		end
		
		class MarkupParser
			class ParsedTag < Tag
				def initialize(name, offset)
					@offset = offset
					
					super(name, false, SymbolicHash.new)
				end
				
				attr :offset
			end
			
			class UnbalancedTagError < StandardError
				def initialize(buffer, opening_tag, closing_tag = nil)
					@buffer = buffer
					@opening_tag = current_tag
					@closing_tag = closing_tag
				end

				attr :buffer
				attr :current_tag
				attr :closing_tag
				
				def start_location
					Trenni::Location.new(@buffer.read, current_tag.offset)
				end
				
				def end_location
					if closing_tag and closing_tag.respond_to? :offset
						Trenni::Location.new(@buffer.read, closing_tag.offset)
					end
				end
				
				def to_s
					if @closing_tag
						"#{start_location}: #{@opening_tag} was not closed!"
					else
						"#{start_location}: #{@opening_tag} was closed by #{@closing_tag}!"
					end
				end
			end
			
			def self.parse(buffer, delegate, entities = Trenni::Entities::HTML5)
				# This is for compatibility with the existing API which passes in a string:
				buffer = Trenni::Buffer(buffer)
				
				self.new(buffer, delegate).parse!
			end
			
			def initialize(buffer, delegate, entities = Trenni::Entities::HTML5)
				@buffer = buffer
				
				@delegate = delegate
				@entities = entities
				
				@current = nil
				@stack = []
			end
			
			def parse!
				Trenni::Parsers.parse_markup(@buffer, self, @entities)
				
				if tag = @stack.pop
					raise UnbalancedTagError.new(@buffer, tag)
				end
			end

			def open_tag_begin(name, offset)
				@current = ParsedTag.new(name, offset)
			end

			def attribute(key, value)
				@current.attributes[key] = value
			end

			def open_tag_end(self_closing)
				if self_closing
					@current.closed = true
					
					@delegate.tag_complete(@current)
				else
					@current.closed = false
					
					@stack << @current
					@delegate.tag_begin(@current)
				end
				
				@current = nil
			end

			def close_tag(name, offset)
				tag = @stack.pop
				
				if tag.name != name
					raise UnbalancedTagError.new(@buffer, tag, ParsedTag.new(name, offset))
				end
				
				@delegate.tag_end(tag)
			end
			
			def doctype(string)
				@delegate.write(string)
			end

			def comment(string)
				@delegate.write(string)
			end

			def instruction(string)
				@delegate.write(string)
			end

			def cdata(string)
				@delegate.write(string)
			end

			def text(string)
				@delegate.text(string)
			end
		end
	end
end
