require 'test_helper'

class CompileCacheTest < Minitest::Test
  include TmpdirHelper

  def test_no_write_permission_to_cache
    path = Help.set_file('a.rb', 'a = 3', 100)
    cp = Help.cache_path(@tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(cp))
    FileUtils.touch(cp)
    FileUtils.chmod(0400, cp)
    assert_raises(Errno::EACCES) { load(path) }
  end

  def test_file_is_only_read_once
    path = Help.set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # This doesn't really *prove* the file is only read once, but
    # it at least asserts the input is only cached once.
    Bootsnap::CompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    Bootsnap::CompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)
    load(path)
    load(path)
  end

  def test_raises_syntax_error
    path = Help.set_file('a.rb', 'a = (3', 100)
    assert_raises(SyntaxError) do
      # SyntaxError emits directly to stderr in addition to raising, it seems.
      capture_io { load(path) }
    end
  end

  def test_no_recache_when_mtime_and_size_same
    path = Help.set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    Bootsnap::CompileCache::ISeq.expects(:input_to_storage).times(1).returns(storage)
    Bootsnap::CompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    Help.set_file(path, 'a = 4', 100)
    load(path)
  end

  def test_recache_when_mtime_different
    path = Help.set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # Totally lies the second time but that's not the point.
    Bootsnap::CompileCache::ISeq.expects(:input_to_storage).times(2).returns(storage)
    Bootsnap::CompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    Help.set_file(path, 'a = 2', 101)
    load(path)
  end

  def test_recache_when_size_different
    path = Help.set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # Totally lies the second time but that's not the point.
    Bootsnap::CompileCache::ISeq.expects(:input_to_storage).times(2).returns(storage)
    Bootsnap::CompileCache::ISeq.expects(:storage_to_output).times(2).returns(output)

    load(path)
    Help.set_file(path, 'a = 33', 100)
    load(path)
  end

  def test_invalid_cache_file
    path = Help.set_file('a.rb', 'a = 3', 100)
    cp = Help.cache_path(@tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(cp))
    File.write(cp, 'nope')
    load(path)
    assert(File.size(cp) > 32) # cache was overwritten
  end
end
