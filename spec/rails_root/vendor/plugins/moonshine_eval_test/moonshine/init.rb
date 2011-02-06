configure(:eval => true)

module EvalTest
  def foo

  end
end

include EvalTest
recipe :foo

