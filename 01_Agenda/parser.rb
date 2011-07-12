# encoding: UTF-8
require 'date'
require 'erb'

require 'rubygems'
require 'nokogiri'
require 'htmlentities'

# hash bindings for ERB
class Hash
  def to_binding(object = Object.new)
    object.instance_eval("def binding_for(#{keys.join(",")}) binding end")
    object.binding_for(*values)
  end
end

class AgendaParser
  HTML_TEMPLATE = %{
    <!DOCTYPE html>

    <html lang="en">
    <head>
      <title>Agenda Campus</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;">
      <!-- jquery mobile -->
      <link rel="stylesheet" href="http://code.jquery.com/mobile/1.0b1/jquery.mobile-1.0b1.min.css" />
      <script src="http://code.jquery.com/jquery-1.6.1.min.js"></script>
      <script src="http://code.jquery.com/mobile/1.0b1/jquery.mobile-1.0b1.min.js"></script>
      <script type="text/javascript" charset="utf-8">
        $("div").live("pagehide", function (event, ui) {
          $(".ui-btn-hover-a", ui.prevPage).removeClass("ui-btn-hover-a").addClass("ui-btn-up-a");
        });
      </script>
      <script src="http://narsil.local:3400/client.js"></script>
      <!-- custom styles -->
      <link rel="stylesheet" href="styles.css" type="text/css" media="screen" charset="utf-8">
    </head>
    <body>
     <% events.keys.sort.each do |day| %>
       <% weekday_short = day.strftime('%a') %>
       <% weekday_full = day.strftime('%A') %>
       <div id="<%= weekday_short %>" data-role="page">  
       <div data-role="header">
        <h1><%= weekday_full %></h1>
        <div data-role="navbar">
          <ul>
          <% events.keys.sort.each do |weekday| %>
            <li><a 
              href="#<%= weekday.strftime('%a') %>"
              <% if weekday == day then %>class="ui-btn-active ui-state-persist"<% end %>
              <% if weekday < day then %>data-direction="reverse"<% end %>
              ><%= weekday.strftime('%a') %></a></li>
          <% end %>
          </ul>
        </div><!-- navbar -->
       </div><!-- header -->
       <div data-role="content">
       <ul data-role="listview" data-filter="true">
       
       <% events[day].sort {|a,b| a[:start_time] <=> b[:start_time]}.each do |event| %>
         <li>
          <!--p><%= event[:name] %></p-->
          <dl>
          <dt><%= event[:name] %></dt>
          <dd class="location"><%= event[:location] %></dd>
          <dd class="time"><%= event[:start_time].strftime("%H:%M") %> – <%= event[:end_time].strftime("%H:%M") %></dd>
          
          </dl>
        </li>      
       <% end %>
       </ul>
       </div>
       </div>
     <% end %>
    </body>
    </html>
   }
   
   # <dd class="time"><%= event[:start_time].strftime("%H:%M") %> <%= event[:end_time].strftime("%H:%M") %></dd>
   

  def initialize(filename)
    file = File.open(filename)
    @doc = Nokogiri::XML(file)
    @entity_coder = HTMLEntities.new
    file.close
  end
  
  def run
    events = @doc.search('entry').map {|event| parse_event(event)}
    events = events.group_by {|x| x[:start_time].to_date }
    
    to_html(events)
  end
  
  protected
  
  # parses a single event
  def parse_event(event)
    name = @entity_coder.decode(event.search('title').text)
    meta = @entity_coder.decode(event.search('summary').text)
    time = get_time(meta)
    location = get_location(meta)
    
    return {:name => name, 
            :start_time => time[0], 
            :end_time => time[1],
            :location => location
           }
  end
  
  # extracts start and end time from string
  def get_time(meta)
    date = meta.match(/\w{3} \d{1,2} \w{3} \d{4}/)[0]
    times = meta.match(/(\d{2}:\d{2}) to (\d{2}:\d{2})/)
    
    start_time = DateTime.parse("#{date} #{times[1]}")
    end_time = DateTime.parse("#{date} #{times[2]}")
    
    return start_time, end_time
  end
  
  # extracts venue from string
  def get_location(meta)
    meta.match(/Where: (.+)\s*<br>/)[1]
  end
  
  # generates html code for the given events
  def to_html(events)
    puts ERB.new(HTML_TEMPLATE).result({:events => events}.to_binding)
  end
end

parser = AgendaParser.new('agenda_campus.xml')
parser.run