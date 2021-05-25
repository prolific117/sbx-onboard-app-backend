require_relative "../test_helper"
class UsersControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  def test_it_creates_user
    @email = "toluyinka@gmail.com"
    post "/user",
         params: {
           first_name: "Tolu",
           last_name: "Yinka",
           company_name: "TheYinks Plc",
           email: @email,
           password: "toluyinka100"
         },
         as: :json

    assert_response :success

    user =  User.find_by(email: @email)
    assert_not_nil(user)
  end
end
