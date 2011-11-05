#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Time-stamp: <2011-11-05 19:35:25 takehiko>

# rensa-generator.rb / ぷよぷよフィールドのクラス

if RUBY_VERSION < "1.9"
  $KCODE = "u"
end

class PuyoField
  def initialize(init_field, opt = nil)
    @debug = 0 # デバッグ表示．0はオフ
    @field = [] # @field[y][x] は下からy段目，左からx列目の内容．いずれも0オリジン
    @width = 0     # フィールド幅
    @height = 0    # フィールド高さ
    @blank = " _"  # 空白扱いする文字
    @inert = "X"   # 「不活性」扱いする文字．4つ以上くっついても消えない
    @ojama = "o"   # おじゃまぷよの文字．4つ以上くっついても消えないが，隣が消えるときに消える
    @delete = "*"  # 消去ぷよの文字
    @check = nil   # 消去可能性判定用の配列
    @rensa = 0     # 連鎖数
    @rensa_stat = [] # 各連鎖の色ぷよと個数の配列
    @delete_max = 0 # 最大連結数（4以上なら消去処理）

    if Hash === opt
      @width = opt[:width] || @width
      @height = opt[:height] || @height
      @blank = opt[:blank] || @blank
      @delete = opt[:delete] || @delete
      @debug = opt[:debug] || @debug
    end

    set_field(init_field)
  end
  attr_accessor :debug, :rensa, :rensa_stat
  attr_accessor :field
  attr_accessor :blank, :inert, :ojama, :delete

  alias :dup_bak dup
  def dup
    obj = dup_bak
    obj.field = Marshal.load(Marshal.dump(@field))
    obj
  end

  def set_field(f)
    return if f.nil? || f.empty?
    f = f.split(/\n/m) if String === f
    f.reverse.each do |f0|
      # 順に乗せていく．そのため，初期配置で空中にあるぷよが表現できない
      load(f0)
    end
  end

  def load(puyos, x = 0, opt_up = false)
    # puyos: ぷよ文字の並び（ArrayまたはString）
    # x: X座標
    # opt_up: trueなら上方向，falseなら右方向に並べる
    puyos = puyos.split(//) if String === puyos
    puyos.each do |c|
      if @width < x + 1
        @width = x + 1
      end
      i = 0 # 最下段
      while true
        if @field[i].nil?
          @field[i] = [@blank[0, 1]] * @width
          @height = i + 1
        end
        if blank?(@field[i][x])
          @field[i][x] = c
          break
        end
        i += 1
      end
      x += 1 unless opt_up
    end
  end

  def undo_pair(x = 0, opt_up = false)
    # 2個取り除き，配列にして返す．取り除けないときはnilを返してフィールドは元に戻す
    # x: X座標
    # opt_up: trueなら上方向，falseなら右方向に1組取り除く
    @field_bak = Marshal.load(Marshal.dump(@field))
    res_a = []
    2.times do |i|
      (@height - 1).downto(0) do |y|
        break if ojama_at?(x, y) || delete_at?(x, y)
        unless blank_at?(x, y)
          res_a.unshift(@field[y][x])
          @field[y][x] = @blank[0, 1]
          break
        end
      end
      x += 1 unless opt_up
    end
    if res_a.size != 2
      redo_field
      return nil 
    end
    res_a
  end

  def redo_field
    # フィールドを，undo_pairの前の状態に戻す
    @field = @field_bak
    @field_bak = nil
  end

  def blank?(c)
    # 文字（またはnil）cが空白か判定
    c.nil? || @blank.index(c)
  end

  def blank_at?(x, y)
    # (x,y)の位置が空白か判定
    @field[y].nil? || blank?(@field[y][x])
  end

  def inert?(c)
    # 文字（またはnil）cが不活性か判定
    !c.nil? && @inert.index(c)
  end

  def inert_at?(x, y)
    # (x,y)の位置が不活性か判定
    !@field[y].nil? && inert?(@field[y][x])
  end

  def ojama?(c)
    # 文字（またはnil）cがおじゃまか判定
    !c.nil? && @ojama.index(c)
  end

  def ojama_at?(x, y)
    # (x,y)の位置がおじゃまか判定
    !@field[y].nil? && ojama?(@field[y][x])
  end

  def delete?(c)
    # 文字（またはnil）cが消去か判定
    !c.nil? && @delete.index(c)
  end

  def delete_at?(x, y)
    # (x,y)の位置が消去か判定
    !@field[y].nil? && delete?(@field[y][x])
  end

  def check_erase
    # フィールド全体について消去可能性判定を行う
    @check = []
    @height.times do |i|
      @check << [0] * @width
    end

    @delete_max = 0

    @height.times do |y|
      @width.times do |x|
        next if @check[y][x] != 0
        d = check_at(x, y, puyo(x, y))
        @delete_max = d if @delete_max < d
      end
    end

    # 消去する箇所があればtrueを返す
    erase?
  end

  def top_at(x)
    # 列の最上段の文字を返す．列に何も積まれていなければ@blank[0,1]を返す．
    (@height - 1).downto(0) do |y|
      return puyo(x, y) if !blank_at?(x, y) && !delete_at?(x, y)
    end
    @blank[0, 1]
  end

  def exist_inert_top
    # 不活性・おじゃまのみからなる列があれば真を返す
    @width.times do |x|
      c = top_at(x)
      return true if inert?(c) || ojama?(c)
    end
    false
  end

  def check_at(x, y, c)
    # 該当位置について消去可能性判定を行う
    puts "check_at(#{x}, #{y}, #{c})" if @debug >= 2
    return 0 if x < 0 || x >= @width || y < 0 || y >= @height
    return 0 if blank_at?(x, y) || inert_at?(x, y) || delete_at?(x, y)
    return 0 if @check[y][x] != 0 || puyo(x, y) != c
    @check[y][x] = 1

    @check[y][x] += check_at(x - 1, y, c) + check_at(x + 1, y, c) + 
      check_at(x, y - 1, c) + check_at(x, y + 1, c)
  end

  def to_s_check
    # 消去可能性の状態を出力する
    str = ""
    @height.times do |y|
      @width.times do |x|
        str += "[#{@check[@height - y - 1][x]}]"
      end
      str += "\n"
    end
    str
  end

  def erase?
    # 消去する（4個以上くっついて消える）箇所があればtrueを返す
    @delete_max >= 4
  end

  def erase
    # 消去する
    erase1
    puts "<<erase>>" if @debug >= 1
    print to_s if @debug >= 1
    erase2
    puts "<<down>>" if @debug >= 1
    print to_s if @debug >= 1
  end

  def erase1
    # 消去できるぷよの文字を@deleteに置き換える
    rensa_a = []
    @height.times do |y|
      @width.times do |x|
        next if delete_at?(x, y) || @check[y][x] < 4
        rensa_a << [puyo(x, y), @check[y][x]]
        erase1_at(x, y, puyo(x, y))
      end
    end
    unless rensa_a.empty?
      @rensa += 1
      @rensa_stat << rensa_a
    end
  end

  def erase1_at(x, y, c)
    # 該当箇所とその連結を@deleteに置き換える
    puts "erase1_at(#{x}, #{y}, #{c})" if @debug >= 2
    return 0 if x < 0 || x >= @width || y < 0 || y >= @height
    return 0 if puyo(x, y) != c
    @field[y][x] = @delete

    erase1_at(x - 1, y, c)
    erase1_at(x + 1, y, c)
    erase1_at(x, y - 1, c)
    erase1_at(x, y + 1, c)
  end

  def erase2
    # @deleteの箇所を詰める（落とす）
    @width.times do |x|
      down = 0
      @height.times do |y|
        if blank_at?(x, y)
          down += 1
        elsif delete_at?(x, y)
          down += 1
          @field[y][x] = @blank[0, 1]
        elsif down > 0
          @field[y - down][x] = @field[y][x]
          @field[y][x] = @blank[0, 1]
        end
      end
    end
  end

  def puyo(x, y)
    # (x,y)の文字を返す
    if blank_at?(x, y)
      @blank[0, 1]
    else
      @field[y][x]
    end
  end

  def to_s(width = @width, height = @height)
    str1 = ""
    height.times do |y|
      line = @field[y]
      str2 = ""
      width.times do |x|
        if !(Array === line) || line.size <= x
          str2 += " "
        else
          c = line[x]
          if blank?(c)
            str2 += " "
          else
            str2 += c
          end
        end
      end
      str1 = str2 + "\n" + str1
    end
    str1
  end

  def execute
    # 消去が終わった状態にして，連鎖数とその状況を返す．
    @rensa = 0
    @rensa_stat = []
    while check_erase
      puts "<<rensa check>>" if @debug >= 1
      print to_s_check if @debug >= 1
      erase
    end
    return @rensa, @rensa_stat
  end

  def simulate
    # 連鎖数とその状況を返す．オブジェクトは変わらない
    p = dup
    p.debug = 0
    p.execute
    return p.rensa, p.rensa_stat
  end

  def start
    puts "<<initial field>>"
    print to_s

    rensa, stat = simulate
    puts "<<result (simulate>>"
    puts "#{rensa} rensa"
    p stat

    execute

    puts "<<result>>"
    puts "#{@rensa} rensa"
    p @rensa_stat
  end

  def check_rensa(cond = 2, opt_undo = true)
    # 規定の連鎖数であることをチェック
    q = self.dup
    r, st = q.execute
    return false unless case cond
                        when Proc
                          cond.call(q)
                        when Fixnum
                          r >= cond
                        else
                          true
                        end

    # undoオプションがなければ，おしまい
    return true unless opt_undo

    # 組ぷよを取り除いて，消去されない状態があるかチェック
    pseudo_success = true
    @width.times do |x|
      q = self.dup
      if q.undo_pair(x, true)
        unless q.check_erase
          pseudo_success = false
        end
      end
    end
    (@width - 1).times do |x|
      q = self.dup
      if q.undo_pair(x, false)
        unless q.check_erase
          pseudo_success = false
        end
      end
    end
    !pseudo_success
  end
end

if __FILE__ == $0
    # 2連鎖
    PuyoField.new((<<EOS).split(/\n/), :debug => 1).start
212
211
121
111
EOS
end
