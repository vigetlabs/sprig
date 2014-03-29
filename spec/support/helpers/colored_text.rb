module ColoredText
  def blue_text(text)
    "\e[34m#{text}\e[0m"
  end

  def green_text(text)
    "\e[32m#{text}\e[0m"
  end

  def orange_text(text)
    "\e[33m#{text}\e[0m"
  end

  def red_text(text)
    "\e[31m#{text}\e[0m"
  end
end
