#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# perm.rb / Array#perm, Array#perm2を追加
# original: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-list/37550

class Array
  def perm_body(r_ary, n, opt)
    if n == 0
      yield r_ary
    elsif n > 0
      lst = opt ? self.uniq : self
      lst.each_index do |i|
        r_ary.push(lst.at(i))
        b = self.dup
        b.delete_at(opt ? b.index(lst.at(i)) : i)
        b.perm_body(r_ary, n - 1, opt) {|arry| yield arry}
        r_ary.pop
      end
    else
      # nop
    end
  end

  # 同一要素を別物として，n個の要素からなる配列を順に与える
  def perm(n = self.size)
    n = self.size if n > self.size
    self.perm_body([], n, nil) {|arry| yield arry}
  end

  # 重複に注意して，n個の要素からなる配列を順に与える
  def perm2(n = self.size)
    n = self.size if n > self.size
    self.perm_body([], n, true) {|arry| yield arry}
  end
end
