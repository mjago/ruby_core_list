require 'nokogiri'
require 'open-uri'
require 'htmlentities'
require_relative 'colour_prompt'

class HTMLParser

  attr_accessor :flags
  attr_accessor :first_post

  def initialize
    clear_pages
    @screen_length = 45
    @first_post = 54980
  end

  def clear_pages
    @flags = {
      :diff => nil,
      :ruby_code => nil,
      :c_code => nil,
      :anon_code => nil,
      :blank_line => 0,
      :msg_start => true,
      :paged => nil
    }
  end

  def get_page
    page_start = @screen_length * (@page_num - 1)
    page_end =  (@screen_length * @page_num) - 1
    @page_lines[page_start..page_end]
  end

  def fetch_page(addr)
    begin      Nokogiri::HTML(open addr)
    rescue
      #      puts 'No Posts Found'
      return nil
    end
  end

  #  def extract_title(doc)
  #    doc.at_css("head title").text
  #  end
  #
  #  def extract_paragraph(doc)
  #    doc.css("body p")
  #  end

  #  def extract_anchors(doc)
  #    doc.css("a")
  #  end

  #  def extract_ids(doc)
  #    ids = []
  #    a = doc.css("a")
  #    a.each do |x|
  #      if x
  #        if x['id']
  #          ids << x['id']
  #        end
  #      end
  #    end
  #    ids
  #  end

  #  def extract_body(page)
  #    page.css 'body'
  #  end

  #  def extract_sect1_title(node)
  #    #    node.css("div.sect1").css("div.titlepage").css("div").css('h2').text
  #    node.css("div.sect1 div.titlepage div h2").text
  #  end

  #  def extract_sect1_paras(node,id)
  #    node.css("div.sect1 div.sect2 p")
  #  end

  #  def extract_para_matching_id(node, id)
  #    paras = extract_paragraph(node)
  #    paras.each do |p|
  #      if p.css("a#" + id)
  #        return p.text
  #      end
  #    end
  #  end

  def save_page(page, name)
    f = File.new(name,'w')
    f.puts page
    f.close
  end

  def read_file(name)
    f = File.open(name)
    #    doc = Nokogiri::XML(f, nil, "ISO-8859-1")
    doc = Nokogiri::XML(f)
    f.close
    doc
  end

  #  def wrap_out(str)
  #    rtn = ''
  #    while str
  #      rtn += str[0...60]
  #      str = str[80..-1]
  #    end
  #    rtn
  #  end

  def decode_html html
    coder = HTMLEntities.new
    coder.decode html
  end

  def param_tbl_format
    {
      date:           {offset: 6,  pos: 0, regex: /^Date\: /},
      from:           {offset: 6,  pos: 1, regex: /^From\: /},
      references:     {offset: 12, pos: 2, regex: /^References\: /},
      issue_id:       {offset: 20, pos: 3, regex: /^X-Redmine-Issue-Id\: /},
      issue_assignee: {offset: 26, pos: 4, regex: /^X-Redmine-Issue-Assignee\: /},
      auto_submitted: {offset: 16, pos: 5, regex: /^Auto-Submitted\: /},
      mail_count:     {offset: 14, pos: 6, regex: /^X-Mail-Count\: /}
    }
  end

  def subject_start_idx str
    if str.index('Subject: ')
      (str.index('Subject: ') + ('Subject: ').size)
    end
  end

  def subject_end_idx str
    if str.index('X-BeenThere: ')
      str.index('X-BeenThere: ') -1
    elsif str.index('To: ')
      str.index('To: ') -1
    end
    # or X-Mailman-Version: 2.1.15
    # or Reply-To: Ruby developers <ruby-core>
  end

  #  def clean(str)
  #    str.gsub("\n",' ')
  #  end

  def parse_subject (str, record)
    #   lines = str.split /\r?\n/
    #   str = ''
    #  lines.each do |line|
    #    if line.lstrip =~ /^Subject:/
    #          colour_puts(:cyan, line, out_file)

    #    puts "str = #{str}"
    start_idx = subject_start_idx(str)
    end_idx = subject_end_idx(str)

    #    if start_idx

    if start_idx && end_idx
      str = str[subject_start_idx(str) .. subject_end_idx(str)]
      #  elsif start_idx
      #    str = str[subject_start_idx(str) .. -1]
      #      str = line
      #    end
    end
    if str == ''
      str = "ERROR - CAN'T PARSE HEADING!!!'"
    end

    str = strip_ruby_core str, record
    str = strip_issue_type str, record
    strip_completion(str).strip.gsub("\n",'').gsub("\t",' ')
  end

  def strip_ruby_core str, record
    str.gsub("[ruby-core:#{record[:mail_count]}]",'')
  end

  def strip_issue_type str, record
    str.gsub("[ruby-trunk - Bug ##{record[:issue_id]}] ",'').
      gsub("[ruby-trunk - Misc ##{record[:issue_id]}] ",'').
      gsub("[ruby-trunk - Feature ##{record[:issue_id]}] ",'')
  end

  def strip_completion str
    str.
      gsub("[Open]",'').
      gsub("[Closed]",'').
      gsub("[Assigned]",'').
      gsub("[Third Party's' Issue]",'')
  end

  def parse_message(str)
    begin
      sub = str[(str.index("Sender: \"ruby-core\" <ruby-core-bounces>") + 40) .. (str.index("</ruby-core-bounces>") -1 )]
      decode_html sub
    rescue
      ''
    end
  end

  def parse_params(page, post)
    record = Hash.new
    record[:id] = post
    str = page.to_s
    split = str.split("\n")
    split.each do |x|
      x = x.to_s
      param_tbl_format.each_pair do |key,val|
        record[key] = x[val[:offset]..-1] if x =~ val[:regex]
      end
    end
    record[:subject] = parse_subject(str, record)
    record[:message] = parse_message(str)
    record
  end

  def next_page
    if @flags[:paged] && (@page_num < @num_of_pages)
      #      @page_num = (@page_num + 1 >= @num_of_pages) ? @num_of_pages : @page_num + 1
      @page_num += 1
      puts get_page
      true
    else
      nil
    end
  end

  def write_subject(subject, outfile)
    attrs = subject.scan(/(\[.*?\])/)
    attrs.flatten!(2)
    attrs.each { |x| subject.gsub!(x,'')}
    colour_print(:blue, subject.strip + ' ', outfile)
    attrs.each { |x| colour_print(:red, x, outfile) }
    colour_print :black, "\n", outfile
    subject.strip.size.times { colour_print(:blue, '-', outfile) }
    colour_print(:blue, "\n", outfile)
    outfile
  end

  def write_id_and_time(id, time, outfile)
    colour_print(:red, '#' + id + ' ' , outfile)
    colour_print(:green, time + "\n", outfile)
    outfile
  end

  def write_from(from, outfile)
    colour_print(:yellow, 'From:  ' + from + "\n", outfile)
    outfile
  end

  def display_record_maybe record
    File.open('out', 'w') do |out_file|
      out_file = write_subject(record[:subject], out_file)
      out_file = write_id_and_time(record[:mail_count], record[:date], out_file)
      out_file = write_from(record[:from], out_file)
      fileslist = extract_fileslist_maybe record[:message]
      redmine_record = extract_redmine_record_maybe record[:message]
      message = redmine_record == nil ? record[:message] : record[:message].gsub(redmine_record,'')
      message = message.gsub(fileslist,'') if fileslist
      footer = "\n"  + "\n" + "-- " + "\n" + 'https://bugs.ruby-lang.org/' +  "\n" + '<'
      message = message.gsub(footer, '') if message
      message.gsub("\n" + "\n" + "\n", "\n")
      #      code = highlight_ruby_maybe(message)
      #      if nil
      #        colour_puts(:dark_grey, (message[0..ruby_source_start(message) - 2]), out_file)
      #        colour_puts(:green, '~~~ruby', out_file)
      #        puts CodeRay.scan(code, :ruby).terminal
      #        #      system "coderay temp.rb"
      #        colour_puts(:green, '~~~', out_file)
      #        colour_puts(:narrative, message[ruby_source_end(message) + '~~~'.size ..-1], out_file)
      #      else
      lines = message.split(/\r?\n/)
      lines.each_with_index do |line,idx|

        if line.lstrip =~ /^>/
          colour_puts(:cyan, line, out_file)

        elsif line =~ /^Issue \#.*\shas been/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Status\schanged\sfrom/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Description\supdated/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Backport\schanged\sfrom/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Category\sset\sto/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Assignee\sset\sto/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Target\sversion\sset\sto/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^%\sDone\schanged\sfrom/
          colour_puts(:blue, line, out_file)

        elsif line =~ /^Applied\sin\schangeset/
          colour_puts(:blue, line, out_file)


        elsif line =~ /^~~~ruby/
          if @flags[:ruby_code] == true
            @flags[:ruby_code] = false
          else
            @flags[:ruby_code] = true
          end

        elsif line =~ /^~~~/
          if @flags[:ruby_code] == true
            @flags[:ruby_code] = false
          elsif @flags[:code] == true
            @flags[:code] = false
          else
            @flags[:code] = true
          end

        elsif line =~ /^```ruby/
          if @flags[:ruby_code] == true
            @flags[:ruby_code] = false
          else
            @flags[:code] = true
          end

        elsif line =~ /^```ruby/
          if @flags[:ruby_code] == true
            @flags[:ruby_code] = false
          else
            @flags[:code] = true
          end

        elsif line =~ /^```/
          if @flags[:ruby_code] == true
            @flags[:ruby_code] = false
          elsif @flags[:code] == true
            @flags[:code] = false
          else
            @flags[:code] = true
          end

        elsif(line.strip == '')
          @flags[:blank_line] += 1
          if @flags[:blank_line] >= 2
            next
          else
            colour_puts(:black, line, out_file)
          end
        else
          @flags[:blank_line] = 0
          if @flags[:msg_start]
            @flags[:msg_start] = nil
            colour_puts(:black, '', out_file)
          end
          if @flags[:ruby_code] || @flags[:code]
            colour_puts(:blue, line, out_file)
          else
            colour_puts(:black, line, out_file)
          end
        end
      end

      colour_puts :black, '', out_file
      colour_puts :green, fileslist, out_file
      colour_puts :yellow, redmine_record, out_file
      out_file
    end

    File.open('out', 'r') do |out_file|
      lines = out_file.readlines
      if lines.size > @screen_length
        @flags[:paged] = true
        @page_lines = lines
        @num_of_pages = lines.size / @screen_length + 1
        @page_num = 1
        puts get_page
        puts
        puts '        ------- more -------        '
        #        sleep 5
        #        system 'clear'
        #        puts lines[screen_length..-1]
      else
        puts lines
      end
    end
  end

  def ruby_source_start msg
    return if(msg == nil)
    msg.index('~~~ruby')
  end

  def ruby_source_end msg
    msg.index('~~~' + "\n")
  end

  def find_ruby_source_start message
    msg = message
    idx = ruby_source_start message
    if idx
      msg[idx + 7..-1]
    end
  end

  def find_ruby_source_end msg
    idx = ruby_source_end(msg)
    if idx
      msg[0..idx - 1]
    end
  end

  def highlight_ruby_maybe msg
    code = find_ruby_source_start msg
    if code
      code = find_ruby_source_end(code)
    end
    if code
      File.open("temp.rb", 'w') do |file|
        file.puts(code)
      end
      code
    end
  end

  def find_fileslist_start msg
    idx = msg.index('---Files--------------------------------')
    if idx
      fileslist = msg[idx..-1]
      #      fileslist = msg[idx..-1]
    end
    fileslist
  end

  def find_fileslist_end msg
    fileslist = ''
    lines = msg.split(/\r?\n/)
    lines.each do |line|
      if line.strip == ''
        break
      else
        fileslist << line + "\n"
      end
    end
    fileslist
  end

  def find_redmine_record_start msg
    idx = msg.index('----------------------------------------')
    msg = idx ? msg[idx + '----------------------------------------'.size..-1] : nil
  end

  def find_redmine_record_end msg
    idx = msg.index('----------------------------------------')
    if idx
      msg = msg[0..idx - 1]
      msg = '----------------------------------------' +
        msg +
        '----------------------------------------'
    end
    msg
  end

  def extract_redmine_record_maybe msg
    redmine_record = find_redmine_record_start msg
    redmine_record = find_redmine_record_end(redmine_record) if redmine_record
  end

  def extract_fileslist_maybe msg
    fileslist = find_fileslist_start msg
    fileslist = find_fileslist_end(fileslist) if fileslist
  end

  def update_posts
    puts 'sorting posts - please wait:'
    post = @first_post
    loop do
      page = fetch_detail post
      break unless page
      post += 1
    end

    @last_post = post - 1
    puts 'posts sorted!'
    sleep 1

    system('clear')
    post = @last_post
    page = fetch_detail post
    record = parse_params(page, post)
    system('clear')
    display_record_maybe record
  end

  def help_header f
    colour_print :blue, "        Ruby Core Mailing List Shell\n", f
    colour_print :blue, "        ----------------------------\n", f
    colour_print :blue, "        ----------------------------\n", f
    colour_print :blue, "                                    \n", f
    colour_print :blue, "               Keystrokes:          \n", f
    colour_print :blue, "                                    \n", f
    f
  end

  def help_key(key, f)
    colour_print :red,   '  ' + key[0], f
    (20 - key[0].size).times { |count| x =((count % 4 == 0) ? '.' : ' ') ; colour_print(:red, x, f)}
    colour_print :black, '  ' + key[1] + "\n\n", f
    f
  end

  def help_page
    keystrokes =
      [['Q.  q', 'Quit.'],
       ['SPACEBAR ','Scroll Page (more) or Next Post'],
       ['Down-Arrow  N.  n',  'Next Post',],
       ['Up-Arrow .  P.  p','Previous Post'],
       ['U.  u','Update Posts'],
       ['F.  f', 'First Post'],
       ['L.  l','Last Post'],
       ['T','Forward Ten Posts'],
       ['t','Back Ten Posts'],
       ['H','Forward One-Hundred Posts'],
       ['h','Back One-Hundred Posts'],
       ['d','Download Page(s)'],
       ['s','Search'],
       ['i','Info Page'],
       ['?','Help Page (This page)']]

    system('clear')
    File.open('out', 'w') do |file|
      file = help_header file
      keystrokes.each { |ks| file = help_key(ks, file)}
      File.open('out', 'r') { |f| f.readlines.each {|line| puts line}}
    end
  end
  def run
    ke = KeyboardEvents.new
    post = @last_post
    loop do
      old_post = post
      case ke.input
      when :previous
        post = post <= @first_post ? @first_post : post - 1
      when :next
        post = post >= @last_post ? @last_post : post + 1
      when :first
        post = @first_post
      when :last
        post = @last_post
      when :last
        post = @last_post
      when :update
        update_posts()
        post = @last_post
      when :back_ten
        post = (post - 10) <= @first_post ? @first_post : post - 10
      when :forward_ten
        post = (post + 10) >= @last_post ? @last_post : post + 10
      when :back_one_hundred
        post = (post - 100) <= @first_post ? @first_post : post - 100
      when :forward_one_hundred
        post = (post + 100) >= @last_post ? @last_post : post + 100
      when :spacebar
        unless next_page
          post = post >= @last_post ? @last_post : post + 1
        end
      when :help
        help_page()
      when :quit
        exit 0
      end

      unless post == old_post
        clear_pages
        page = fetch_detail post
        break unless page
        record = parse_params(page, post)
        system('clear')
        display_record_maybe record
      end
    end
  end

  def fetch_xml(address)
    xml = Nokogiri::HTML(open(address))
    puts xml
    exit 1
  end

  def fetch_detail(post)
    #      xml = fetch_xml("http://blade.nagaokaut.ac.jp/ruby/ruby-core/" + post.to_s)
    unless File.file?("posts/post_#{post.to_s}.txt")
      address = "http://blade.nagaokaut.ac.jp/ruby/ruby-core/" + post.to_s
      puts "fetching post #{post}"
      page = fetch_page(address)
      return unless page
      save_page page, "posts/post_#{post}.txt"
      #      sleep 5
    end
    read_file 'posts/post_' + post.to_s + '.txt'
  end
end

class KeyboardEvents
  def input
    begin
      system("stty raw -echo")
      str = STDIN.getc
      #      puts str.inspect
    ensure
      system("stty -raw echo")
    end
    #    puts "str = #{str}"
    case str
    when "q",'Q'
      :quit
    when 'p', 'P', 'A'
      :previous
    when 'n', 'N', 'B'
      :next
    when 'f', 'F'
      :first
    when 'l', 'L'
      :last
    when 'u', 'U'
      :update
    when 't'
      :back_ten
    when 'T'
      :forward_ten
    when 'h'
      :back_one_hundred
    when 'H'
      :forward_one_hundred
    when ' '
      :spacebar
    when '?'
      :help
    else
      :unknown
    end
  end
end

#       #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #       #

if __FILE__ == $0
  hp = HTMLParser.new
  hp.update_posts
  hp.run
end
