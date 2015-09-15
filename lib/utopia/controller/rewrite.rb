# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative '../http'
require_relative '../path/matcher'

module Utopia
	class Controller
		class RewriteError < ArgumentError
		end
		
		module Rewrite
			def self.prepended(base)
				base.extend(ClassMethods)
			end
			
			class Rule
				def initialize(arguments, block)
					@arguments = arguments
					@block = block
				end
				
				attr :arguments
				attr :block
				
				def apply_match_to_context(match_data, context)
					match_data.names.each do |name|
						context.instance_variable_set("@#{name}", match_data[name])
					end
				end
			end
			
			class ExtractPrefixRule < Rule
				def apply(context, request, path)
					@matcher ||= Path::Matcher.new(@arguments)
					
					if match_data = @matcher.match(path)
						apply_match_to_context(match_data, context)
						
						if @block
							context.instance_exec(request, path, match_data, &@block)
						end
						
						return match_data.post_match
					else
						return input
					end
				end
			end
			
			class Rewriter
				def initialize
					@rules = []
				end
				
				def extract_prefix(**arguments, &block)
					@rules << ExtractPrefixRule.new(arguments, block)
				end
				
				def apply(context, request, path)
					@rules.each do |rule|
						path = rule.apply(context, request, path)
					end
					
					return path
				end
			end
			
			module ClassMethods
				def rewrite
					@rewriter ||= Rewriter.new
				end
			end
			
			def rewrite(request, path)
				# Rewrite the path if possible, may return a String or Path:
				self.class.rewrite.apply(self, request, path)
			end
			
			# Rewrite the path before processing the request if possible.
			def passthrough(request, path)
				path.components = rewrite(request, path).components
				
				super
			end
		end
	end
end
