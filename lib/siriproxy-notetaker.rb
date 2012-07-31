require 'cora'
require 'siri_objects'

class SiriProxy::Plugin::NoteTaker < SiriProxy::Plugin

  def initialize(config)
  end
  
  def getNum(num)
    if /Ten/i.match(num) or /10/.match(num)
      number = 10
    elsif /Eleven/i.match(num) or /11/.match(num)
      number = 11
    elsif /Twelve/i.match(num) or /Twelfth/i.match(num) or /12/.match(num)
      number = 12
    elsif /Thirteen/i.match(num) or /13/.match(num)
      number = 13
    elsif /Fourteen/i.match(num) or /14/.match(num)
      number = 14
    elsif /Fifteen/i.match(num) or /15/.match(num)
      number = 15
    elsif /Two/i.match(num) or /Second/i.match(num) or /2/.match(num)
      number = 2
    elsif /Three/i.match(num) or /Third/i.match(num) or /3/.match(num)
      number = 3
    elsif /Four/i.match(num) or /4/.match(num)
      number = 4
    elsif /Five/i.match(num) or /Fifth/i.match(num) or /5/.match(num)
      number = 5
    elsif /Six/i.match(num) or /6/.match(num)
      number = 6
    elsif /Seven/i.match(num) or /7/.match(num)
      number = 7
    elsif /Eight/i.match(num) or /8/.match(num)
      number = 8
    elsif /Nine/i.match(num) or /Ninth/i.match(num) or /9/.match(num)
      number = 9
    elsif /One/i.match(num) or /First/i.match(num) or /1/.match(num)
      number = 1
    else
      number = nil
    end
    if number != nil
      return number
    else
      again = ask "I'm sorry but didn't get that. Could you say the number again?"
      getNum(again)
    end
  end
    
  def getClient()
    my2 = Mysql2::Client.new(:host => "#{$APP_CONFIG.db_host}", :username => "#{$APP_CONFIG.db_user}", :password => "#{$APP_CONFIG.db_pass}", :database => "#{$APP_CONFIG.db_database}")
    # TODO: Prevent SQL injection
    client = []
    my2.query("SELECT * FROM `siri`.`clients` ORDER BY `last_login` ASC LIMIT 1", :as => :array).each do |rows|
      client << {:fname => rows[1],
                 :nickname => rows[2],
                 :appleDBid => rows[3],
                 :appleAccountid => rows[4],
                 :valid => rows[5],
                 :devicetype => rows[6],
                 :deviceOS => rows[7],
                 :date_added => rows[8],
                 :last_login => rows[9],
                 :last_ip => rows[10]}
    end
    return client
  end
  
  listen_for /Write (this|it) down/i do
    current = getClient()
    if !(File::exists?("/.siriproxyTMP/#{current.fname}/note_#{15}.txt"))
      wtw = ask "What would you like for me to write down?"
      makeNote = SiriAddViews.new
      makeNote.make_root(last_ref_id)
      makeNote.views << SiriAnswerSnippet.new([SiriAnswer.new("Note:", [SiriAnswerLine.new("#{wtw}")])])
      send_object makeNote
      createNote = confirm "Are you sure you want to make this note?"
      if createNote
        Dir.mkdir("/.siriproxyTMP/#{current.fname}") unless Dir::exists?("/.siriproxyTMP/#{current.fname}")
        for x in (1..15) do
          if File::exists?("/.siriproxyTMP/#{current.fname}/note_#{x}.txt") == false
            @whichFile = x
            tempfile = File.new("/.siriproxyTMP/#{current.fname}/note_#{@whichFile}.txt", "w+")
            tempfile.syswrite(wtw)
            tempfile.close
            say "OK. I wrote that down. Ask me \"What did I write\" when you want to know what you've said."
            break
          end
        end
      else
        say "OK. I'm erasing that for you."
      end
    else
      say "You've used up all of your allocated slots. You need to delete a note before creating another one."
    end
    request_completed
  end
  
  listen_for /What did (I|you) write/i do
    notes = SiriAddViews.new
    notes.make_root(last_ref_id)
    current = getClient()
    for x in (1..15) do
      if File::exists?("/.siriproxyTMP/#{current.fname}/note_#{x}.txt")
        noteLines = []
        fileLines = IO.readlines("/.siriproxyTMP/#{current.fname}/note_#{x}.txt")
          for y in (0..fileLines.length) do
            noteLines << SiriAnswerLine.new("#{fileLines[y]}")
          end
        note = SiriAnswer.new("Note #{x}:", noteLines)
      end
      notes.views << SiriAnswerSnippet.new([note])
    end
    send_object notes
    delete = confirm "Would you like to delete any of your notes right now?"
    if delete
      @whichFile = ask "Which note do you want to delete?"
      @whichFile = getNum(@whichFile)
      noteToDelete = SiriAddViews.new
      noteToDelete.make_root(last_ref_id)
      toDeleteLines = []
      fileLines = IO.readlines("/.siriproxyTMP/#{current.fname}/note_#{@whichFile}.txt")
        for x in (0..fileLines.length)
          toDeleteLines << SiriAnswerLine.new("#{fileLines[x]}")
        end
      toDelete = SiriAnswer.new("Note #{@whichFile}:", toDeleteLines)
      noteToDelete.views << SiriAnswerSnippet.new([toDelete])
      reallyDelete = confirm "Are you sure this is the note you want to delete?"
      if reallyDelete
        File.delete("/.siriproxyTMP/#{current.fname}/note_#{@whichFile}.txt") if File::exists?("/.siriproxyTMP/#{current.fname}/note_#{@whichFile}.txt")
        for x in (@whichFile..15)
          File::rename("/.siriproxyTMP/#{current.fname}/note_#{x}.txt","/.siriproxyTMP/#{current.fname}/note_#{x-1}.txt") if File::exists?("/.siriproxyTMP/#{current.fname}/note_#{x}.txt")
        end
        say "Note deleted!"
      else
        say "OK then. I'm not deleting that note."
      end
    end
    request_completed
  end
  
  listen_for /Delete my notes/i do
    current = getClient()
    delete = confirm "Are you sure you want to delete all of your notes?"
    if delete
        for x in (1..15)
          File.delete("/.siriproxyTMP/#{current.fname}/note_#{x}.txt") if File::exists?("/.siriproxyTMP/#{current.fname}/note_#{x}.txt")
        end
        say "Notes deleted!"
    else
      say "OK then. I'm not deleting your notes."
    end
    request_completed
  end
end
