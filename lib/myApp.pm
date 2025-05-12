package myApp;
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use Mojolicious::Plugin::Bcrypt;
use Mojo::JWT;

# This method will run once at server start
sub startup ($self) {

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig');

    $self->plugin('bcrypt');

    # Configure the application
    $self->secrets( $config->{secrets} );

    $self->helper(
        pg => sub {
            state $pg = Mojo::Pg->new( shift->config('postgres') );
        }
    );

    $self->helper(
        dbhandle => sub {
            state $vikidb = myApp::Model::Database->new( pg => shift->pg );
        }
    );

    $self->helper(
        current_user_id => \&myApp::Controller::Auth::current_user_id );

    $self->helper(
        current_user_role => sub ($c) {
            my $token   = $c->cookie('auth_token') or return;
            my $payload = eval {
                Mojo::JWT->new( secret => 'your-secret-key' )->decode($token);
            };
            return $payload->{role} if $payload;
            return;
        }
    );

    $self->helper(
        is_admin => sub ($c) {
            return $c->current_user_role && $c->current_user_role eq 'admin';
        }
    );

    # Router
    my $r = $self->routes;
    $r->post('/register-user')->to('Auth#registerUser');
    $r->post('/login')->to('Auth#login');
    $r->get('/logout')->to('Auth#logout');
    $r->put('/change-password')->to('Auth#changePassword');
    $r->put('edit-user')->to('Auth#editUser');

    $r->post('/create-ad')->to('Ad#createAd');
    $r->get('/all-ads')->to('Ad#getAllAds');
    $r->put('/ad-edit/:id')->to('Ad#editAd');
    $r->delete('/ad-delete/:id')->to('Ad#deleteAd');
    $r->get('/ad-search')->to('Ad#searchAd');
    $r->put('/ad-update-status/:id')->to('Ad#updateStatus');

    $r->post('/create-comment/:id')->to('Comment#createComment');
    $r->put('/edit-comment/:id')->to('Comment#editComment');
    $r->get('/all-comments')->to('Comment#getAllComments');
    $r->delete('/comment-delete/:id')->to('Comment#deleteComment');

}

1;
