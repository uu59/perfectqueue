
module PerfectQueue


class RDBBackend < Backend
  def initialize(uri, table)
    require 'sequel'
    @uri = uri
    @table = table
    @db = Sequel.connect(@uri)
    init_db(@uri.split(':',2)[0])
  end

  private
  def init_db(type)
    sql = ''
    case type
    when /mysql/i
      sql << "CREATE TABLE IF NOT EXISTS `#{@table}` ("
      sql << "  id VARCHAR(256) NOT NULL,"
      sql << "  timeout INT NOT NULL,"
      sql << "  data BLOB NOT NULL,"
      sql << "  created_at INT NOT NULL,"
      sql << "  PRIMARY KEY (id)"
      sql << ") ENGINE=INNODB;"
    else
      sql << "CREATE TABLE IF NOT EXISTS `#{@table}` ("
      sql << "  id VARCHAR(256) NOT NULL,"
      sql << "  timeout INT NOT NULL,"
      sql << "  data BLOB NOT NULL,"
      sql << "  created_at INT NOT NULL,"
      sql << "  PRIMARY KEY (id)"
      sql << ");"
    end
    connect {
      @db.run sql
    }
  end

  def connect(&block)
    begin
      block.call
    ensure
      @db.disconnect
    end
  end

  public
  def list(&block)
    @db.fetch("SELECT id, timeout, data, created_at FROM `#{@table}` ORDER BY created_at ASC;") {|row|
      block.call(row[:id], row[:created_at], row[:data], row[:timeout])
    }
  end

  MAX_SELECT_ROW = 128

  def acquire(timeout, now=Time.now.to_i)
    connect {
      while true
        rows = 0
        @db.fetch("SELECT id, timeout, data, created_at FROM `#{@table}` WHERE timeout <= ? ORDER BY created_at ASC LIMIT #{MAX_SELECT_ROW};", now) {|row|
          n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=? AND timeout=?;", timeout, row[:id], row[:timeout]].update
          if n > 0
            return row[:id], row[:created_at], row[:data]
          end
          rows += 1
        }
        if rows < MAX_SELECT_ROW
          return nil
        end
      end
    }
  end

  def finish(id)
    connect {
      n = @db["DELETE FROM `#{@table}` WHERE id=?;", id].delete
      return n > 0
    }
  end

  def update(id, timeout)
    connect {
      n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=?;", timeout, id].update
      if n <= 0
        raise CanceledError, "Task id=#{id} is canceled."
      end
      return nil
    }
  end

  def cancel(id)
    finish(id)
  end

  def submit(id, data, time=Time.now.to_i)
    connect {
      n = @db["INSERT INTO `#{@table}` (id, timeout, data, created_at) VALUES (?, ?, ?, ?);", id, time, data, time].insert
      nil
    }
  end
end


end

