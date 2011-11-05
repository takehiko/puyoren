#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Time-stamp: <2011-11-05 20:51:42 takehiko>

# rensa-generator.rb / ぷよぷよ連鎖パターン生成のためのクラス
# see also: http://d.hatena.ne.jp/takehikom/20090917/1253135033

if RUBY_VERSION < "1.9"
  $KCODE = "u"
  require "rubygems"
end

require "multiset" # gem install multiset
$LOAD_PATH.unshift(File.dirname(File.expand_path(__FILE__)))
require "perm.rb"
require "puyo-field.rb"

$use_fork = false # 使用する列数ごとに生成プロセスを分けるなら真

class RensaGenerator
  def initialize(puyos, opt = nil)
    @puyos = puyos || "11112222" # 使用するぷよ
    @width = 0  # フィールド幅
    @height = 0 # フィールド高さ
    @rensa = 2  # 解と判断する連鎖数
    @trial = 0  # 連鎖数を検査したフィールドの数
    @number = 0 # 見つけた解の個数
    @file = nil # ファイル名．String以外で$use_forkが偽なら標準出力へ
    @cond = nil
    if Hash === opt
      @width = opt[:width] || @width
      @height = opt[:height] || @height
      @rensa = opt[:rensa] || @rensa
      @file = opt[:file] || @file
      @cond = opt[:cond] || @cond
    end
  end
  attr_reader :trial, :number

  def generate(w, io = $stdout, opt_print_date = false)
    if io != $stdout && opt_print_date
      t1 = Time.now
      io.puts "Date: #{t1}"
    end
    pf0 = PuyoField.new([], :width => w, :height => @height, :debug => 0)
    if (@puyos & (pf0.inert + pf0.ojama).split(//)).empty?
      inert_pattern = nil
    else
      inert_pattern = /^[#{pf0.inert + pf0.ojama}]+$/
    end
    @puyos.perm2(w) do |base|
      base_s = base.join
      symm = (base_s <=> base_s.reverse) # 0のとき左右対称
      next if symm > 0 # 鏡像除外
      symm = 9999 if w == 1 # 幅1のときは鏡像除外を考えない
      next if inert_pattern && (inert_pattern =~ base_s)  # 最下段が消えないぷよばかりの状態を除外

      float0 = (Multiset[*@puyos] - Multiset[*base]).to_a
      float1 = float0 + [":"] * (w - 1)
      float1.perm2 do |float2|
        if symm == 0
          # baseが左右対称のときの鏡像除外
          float3 = [""]
          float2.each do |c|
            if c == ":"
              float3.unshift(":")
              float3.unshift("")
            else
              float3[0] += c
            end
          end
          next if float2.join > float3.join
        end

        @trial += 1
        pf = pf0.dup
        pf.load(base)
        x = 0
        float2.each do |c|
          if c == ":"
            x += 1
          else
            pf.load(c, x)
          end
        end

        if inert_pattern && pf.exist_inert_top  ## premanently false? ##
          next
        end

        io.puts "[Trial #{@trial}]" if $DEBUG
        pf2 = pf.dup
        if pf.check_rensa(@cond || @rensa)
          @number += 1
          io.puts "No.#{@number}"
          unless $DEBUG
            io.print pf2
            io.puts
          end
        end
        if $DEBUG
          io.print pf2
          io.puts
        end
      end
    end

    if io != $stdout && opt_print_date
      io.puts "Tried #{@trial} cases and found #{@number} solutions."
      t2 = Time.now
      io.puts "Date: #{t2}"
      io.puts "Execution time: #{t2 - t1} sec."
    end
  end

  def generate_without_fork
    @puyos = @puyos.split(//) if String === @puyos
    f_out = @file.nil? ? $stdout : open(@file, "w")
    1.upto(@width) do |i|
      generate(i, f_out, false)
    end
    f_out.puts "Tried #{@trial} cases and found #{@number} solutions."
    f_out.close unless @file.nil?
  end

  def generate_with_fork
    raise "file name required." unless String === @file
    @puyos = @puyos.split(//) if String === @puyos
    pid_a = []
    1.upto(@width) do |i|
      # 列ごとに子プロセスを生成して連鎖を作成
      pid = fork
      if pid.nil?
        generate(i, open("#{@file}_#{i}", "w"), true)
        exit
      end
      pid_a << pid
    end
    pid_a.each do |pid|
      # 全ての子プロセスが終わるのを待つ
      Process.detach(pid).join
    end

    # 集計
    tri = 0
    num = 0
    open(@file, "w") do |fout|
      1.upto(@width) do |i|
        open("#{@file}_#{i}") do |fin|
          fin.each_line do |line|
            case line
            when /^Tried\D*(\d+)/
              tri += $1.to_i
            when /^Date/
              # do nothing
            when /^Exec/
              # do nothing
            when /^No./
              num += 1
              fout.puts "No.#{num}"
            else
              fout.print line
            end
          end
        end
      end
      fout.puts "Tried #{tri} cases and found #{num} solutions."
    end
  end

  def self.setup_start
    if $use_fork
      alias :start :generate_with_fork
    else
      alias :start :generate_without_fork
    end
  end
end

RensaGenerator.setup_start

if __FILE__ == $0
  # 4->4個の2連鎖
  RensaGenerator.new("11112222", :width => 6, :height => 12,
                     :cond => Proc.new {|p|
                       p.rensa >= 2 && p.rensa_stat[0][0][0] == "1"
                     }).start
end
