package myApp::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojolicious::Plugin::Bcrypt;
use Mojo::JWT;





sub current_user_id ($self) {
    my $jwt_secret = 'your-secret-key';  
    my $token = $self->cookie('auth_token') or return;


    my $payload = eval {
        Mojo::JWT->new(secret => $jwt_secret)->decode($token);
    };

    if ($payload) {
        $self->app->log->debug("Decoded payload: " . join(", ", %$payload));  
        return $payload->{id};
    } else {
        $self->app->log->debug("Failed to decode token: $@");
    }

    return;
}


sub registerUser ($self) {
    my $username = $self->param("username");
    my $password = $self->param("password");

    unless ( $username && $password ) {
        return $self->render(
            json   => { error => "Username and password required" },
            status => 400
        );
    }

    my $exist = $self->pg->db->query( 'SELECT id FROM users WHERE username = ?',
        $username )->hash;
    if ($exist) {
        return $self->render(
            json   => { error => "Username already exists" },
            status => 409
        );
    }

    my $crypted_pass = $self->bcrypt($password);

    $self->pg->db->query(
        'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
        $username, $crypted_pass, 'user' );

    $self->render( json => { success => \1 } );
}


sub login ($self) {
    my $username = $self->param("username");
    my $password = $self->param("password");

    unless ( $username && $password ) {
        return $self->render(
            json   => { error => "Username and password required" },
            status => 400
        );
    }

    my $user = $self->pg->db->query(
        'SELECT id, username, password, role FROM users WHERE username = ?',
        $username )->hash;

    unless ($user) {
        return $self->render(
            json   => { error => "Invalid username or password" },
            status => 401
        );
    }

    if ( $self->bcrypt_validate( $password, $user->{password} ) ) {

        my $jwt_secret = 'your-secret-key';
        my $jwt_token = Mojo::JWT->new(
    claims => {
        id       => $user->{id},
        username => $user->{username},
        role     => $user->{role},
    },
    secret => $jwt_secret
    )->encode; 
        $self->cookie('auth_token'=>$jwt_token, {http_only=>1, secure=>1});

        return $self->render(
            json => {
                success => \1,
                user    => {
                    id       => $user->{id},
                    username => $user->{username},
                    role     => $user->{role},
                },
                token => $jwt_token,
            }
        );
    }
    else {
        return $self->render(
            json   => { error => "Invalid username or password" },
            status => 401
        );
    }
}


sub logout($self) {
  $self->cookie('auth_token'=>''=>{expires=>-1});
  return $self->render(json=>{success=>\1, message=>'Logged out successfuly'});
};


sub changePassword ($self) {
    my $current_password = $self->param('current_password');
    my $new_password = $self->param('new_password');

    unless ($current_password && $new_password){
        return $self->render(
            json => {error => 'Current and new password required'},
            status => 400
        );
    }

    my $token = $self->cookie('auth_token');
    unless ($token){
        return $self->render(error => 'Authentication required', status => 403);
    }

    my $jwt_secret = 'your-secret-key';

    my $payload = eval {
        Mojo::JWT->new(secret => $jwt_secret)->decode($token);
    };

    if($@ || !$payload){
        return $self->render(json => {error => 'Invalid token'}, status => 401)
    };

    my $user_id = $payload->{id};

    my $user = $self->pg->db->query('SELECT id, password FROM users WHERE id=?', $user_id)->hash;

    unless ($user){
        return $self->render(json => { error => 'User not found'}, status => 404);
    };

    unless ($self->bcrypt_validate($current_password, $user ->{password})){
        return $self->render( json => { error => 'Current password is incorrect'}, status => 400);
    };

    my $crypted_pass = $self->bcrypt($new_password);

    $self->pg->db->query('UPDATE users SET password=? WHERE id=?', $crypted_pass, $user_id); 
    return $self->render( json => { success => \1, message => 'Password changed successfully'});


};



sub editUser($self){  

    my $user_id = $self->current_user_id;
    return $self->render( json => { error => 'Unathorized'}, status => 401)
      unless $user_id;
    
    my $new_username = $self->param('new_username');

    my $user = $self->pg->db->query('SELECT * from users WHERE id=?', $user_id)->hash;
    
    return $self->render( json => { error => 'User not found or not authorized'}, status => 400)
        unless $user_id;
    
    $self->pg->db->query('UPDATE users SET username=? WHERE id=?', $new_username, $user_id );

    $self->render(
        json => {
          success => 1,
          message => 'User update successfully',
          user => {
              id => $user_id,
              username => $new_username,
          }
        }
    );

};





1;
      #unless $user_id;
