#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Time-stamp: <2011-11-06 04:44:02 takehiko>

# generate.rb / ぷよぷよ連鎖パターン生成

$LOAD_PATH.unshift(File.dirname(File.expand_path(__FILE__)))
require "rensa-generator.rb"

def write_date(message = "")
  open(".date", "a") do |f_out|
    f_out.puts "#{message}Date: #{Time.now}"
  end
end

def write_begin_date(label)
  write_date("Begin(#{label}) ")
end

def write_end_date(label)
  write_date("End(#{label})   ")
end

def generate
  # 4個，4個の2連鎖
  label = "4-4"
  write_begin_date(label)
  RensaGenerator.new("11112222", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       p.rensa == 2 && p.rensa_stat[0][0][0] == "1"
                     }).start
  write_end_date(label)
end

def generate2
  # 5個，5個の2連鎖
  label = "5-5"
  write_begin_date(label)
  RensaGenerator.new("1111122222", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       next false if p.rensa < 2
                       r1 = p.rensa_stat[0]
                       r2 = p.rensa_stat[1]
                       r1.size == 1 && r1[0][0] == "1" && r1[0][1] == 5 &&
                       r2.size == 1 && r2[0][0] == "2" && r2[0][1] == 5
                     }).start
  write_end_date(label)

  label = "4-4-4"
  write_begin_date(label)
  # 4個，4個，4個の3連鎖（かなり時間がかかる）
  RensaGenerator.new("111122223333", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       next false if p.rensa < 3
                       p.rensa_stat[0][0][0] == "1" && p.rensa_stat[1][0][0] == "2"
                     }).start
  write_end_date(label)
end

def generate3
  # 4個，5個の2連鎖
  label = "4-5"
  write_begin_date(label)
  RensaGenerator.new("111122222", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       next false if p.rensa < 2
                       r2 = p.rensa_stat[1]
                       r2.size == 1 && r2[0][0] == "2" && r2[0][1] == 5
                     }).start
  write_end_date(label)

  # 5個，4個の2連鎖
  label = "5-4"
  write_begin_date(label)
  RensaGenerator.new("111112222", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       next false if p.rensa < 2
                       r1 = p.rensa_stat[0]
                       r1.size == 1 && r1[0][0] == "1" && r1[0][1] == 5
                     }).start
  write_end_date(label)
end

def generate4
  # 4個，4個の2連鎖（無駄ぷよ1個あり）
  label = "4-4_x"
  write_begin_date(label)
  RensaGenerator.new("11112222X", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       p.rensa >= 2 && p.rensa_stat[0][0][0] == "1"
                     }).start
  write_end_date(label)

  # 4個，4個の2連鎖（無駄ぷよ2個あり）
  label = "4-4_xx"
  write_begin_date(label)
  RensaGenerator.new("11112222XX", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       p.rensa >= 2 && p.rensa_stat[0][0][0] == "1"
                     }).start
  write_end_date(label)

  label = "5-5_x"
  write_begin_date(label)
  # 5個，5個の2連鎖（無駄ぷよ1個あり）
  RensaGenerator.new("1111122222X", :width => 6, :height => 12,
                     :file => "#{label}.txt",
                     :cond => Proc.new {|p|
                       next false if p.rensa < 2
                       r1 = p.rensa_stat[0]
                       r2 = p.rensa_stat[1]
                       r1.size == 1 && r1[0][0] == "1" && r1[0][1] == 5 &&
                       r2.size == 1 && r2[0][0] == "2" && r2[0][1] == 5
                     }).start
  write_end_date(label)
end

# du_a = [["with_fork", true]] # プロセス分割する方法のみ
# du_a = [["without_fork", false]] # プロセス分割しない方法のみ
du_a = [["with_fork", true], ["without_fork", false]] # 両方

du_a.each do |d, u|
  $use_fork = u
  RensaGenerator.setup_start
  Dir.mkdir(d) unless test(?d, d)
  Dir.chdir(d) do
    generate
    # 下のコメントを取り除けば，より多くのケースで実行する
    # generate2
    # generate3
    # generate4
  end
end
