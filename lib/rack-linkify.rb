require 'rack-plastic'

module Rack
  class Linkify < Plastic
    module Utils
      def self.linkify_content(content, options = {})
        parsed_document = Nokogiri::HTML.parse(content)

        result = self.find_candidate_links(parsed_document)
        result = self.linkify(result, options)

        content.replace(result)
      end

      def self.find_candidate_links(doc)
        doc.at_css("body").traverse do |node|
          if node.text? && node.parent.name != 'textarea' && node.parent.name != 'option'
            update_text(node, self.mark_links(node.content))
          end
        end
      end

      def self.linkify(html, options = {})
        option_attributes = options.map do |attribute, value|
          "#{attribute}=\"#{value}\""
        end.join(" ")

        html.gsub!(/beginninganchor1(?!http)/, 'beginninganchor1http://')
        html.gsub!('beginninganchor1', '<a href="')
        html.gsub!('beginninganchor2', '" ' + option_attributes + '>')
        html.gsub!('endinganchor', '</a>')
        html
      end

      def self.mark_links(text)
        new_text = text
        
        # A pattern-matching algorithm that would correctly detect URLs 100% of the time
        # would be prohibitively complex. For example, if a URL in a sentence is followed
        # by a comma, like http://www.google.com, we would want to match the URL but
        # skip the comma. However, commas are allowed in URLs. So there are a lot
        # of edge cases that make a complete solution very complex.
        #
        # The following strategy has the benefits of being relatively straightforword
        # to implement as well as having high accuracy. Text is scanned for top-level
        # domains, and if one is found it is assumed to be a URL.
   
        common_gtlds = "com|net|org|edu|gov|info|mil|name|mobi|biz"
   
        new_text.gsub!(/\b
                        (\S+\.(#{common_gtlds}|[a-z]{2}(?![a-z]))\S*) # match words that contain common
                                                                      # top-level domains or country codes
                                                                      # 
                        (\.|\?|!|:|,|\))*                             # if the URL ends in punctuation,
                                                                      # assume the punction is grammatical
                                                                      # and is not part of the URL
                                                                      # 
                        \b/x,
          # We mark the text with phrases like "beginninganchor1". That's because it's
          # much easier to replace these strings later with anchor tags rather than work within
          # Nokogiri's document structure to add a new node in the middle of the text.
         'beginninganchor1\0beginninganchor2\0\3endinganchor')
   
        new_text
      end
    end

    include Rack::Linkify::Utils

    def change_nokogiri_doc(doc)
      Rack::Linkify.find_candidate_links(doc)
      doc
    end
    
    def change_html_string(html)
      Rack::Linkify.linkify(html, options)
    end
  end
end
