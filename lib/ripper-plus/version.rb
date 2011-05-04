module RipperPlus
  module Version
    MAJOR = 1
    MINOR = 2
    PATCH = 0
    BUILD = ''

    if BUILD.empty?
      STRING = [MAJOR, MINOR, PATCH].compact.join('.')
    else
      STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
    end
  end
end