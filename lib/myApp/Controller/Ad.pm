package myApp::Controller::Ad;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub createAd ($self) {
    my $user_id = $self->current_user_id;
    return $self->render( json => { error => "Unauthorized" }, status => 401 )
      unless $user_id;

    my $title = $self->param('title');
    my $category = $self->param('category');

    return $self->render(
        json   => { success => 0, error => 'Missing data' },
        status => 400
    ) unless $title;

    $self->pg->db->query( 'INSERT INTO ads (user_id, title, status, category) VALUES (?, ?, ?, ?)',
        $user_id, $title, 1, $category );

    $self->render(
        json => {
            success => 1,
            message => 'Ad created successfully',
            ad      => {
                user_id => $user_id,
                title   => $title,
                status  => 1,
                category=> $category
            }
        }
    );
}

sub editAd ($self) {
    my $user_id = $self->current_user_id;
    return $self->render( json => { error => "Unauthorized" }, status => 401 )
      unless $user_id;

    my $ad_id = $self->stash('id');
    my $title = $self->param('title');

    return $self->render(
        json   => { success => 0, error => 'Missing title' },
        status => 400
    ) unless $title;

    my $ad =
      $self->pg->db->query( 'SELECT * from ads WHERE id = ? AND user_id = ?',
        $ad_id, $user_id )->hash;

    my $category = $self->param('category');
    $category = $ad->{category} unless defined $category;


    return $self->render(
        json   => { success => 0, error => 'Ad not found or not authorized' },
        status => 400
    ) unless $ad;

    $self->pg->db->query( 'UPDATE ads SET title=?, category=? WHERE id=?', $title, $category, $ad_id );

    $self->render(
        json => {
            success => 1,
            message => 'Ad update successfuly',
            ad      => {
                id      => $ad_id,
                user_id => $user_id,
                title   => $title,
                category=> $category
            }
        }
    );

}

sub getAllAds ($self) {

    my $page = $self->param('page') || 1;
    my $limit = $self->param('limit') || 10;
    my $offset;
    my $offest = ($page - 1) * $limit;


    my $ads = $self->pg->db->query('SELECT * from ads WHERE status=1 ORDER BY created_at DESC LIMIT ? OFFSET ?',
        $limit, $offset)->hashes->to_array;

    my $total = $self->pg->db->query('SELECT COUNT(*) AS count FROM ads WHERE status=1')->hash->{count};

    $self->render(
        json => {
            success => 1,
            message => 'Get all ads successfuly',
            page    => $page,
            limit   => $limit,
            total   => $total,
            ads     => $ads,
        }
    );

}

sub deleteAd ($self) {

    return $self->render(json => {error => 'Unauthorized'}, status => 403)
      unless $self->is_admin;


    my $ad_id = $self->stash('id');

    return $self->render(
        json   => { error => "Ad ID is required" },
        status => 400
    ) unless $ad_id;

    my $ad =
      $self->pg->db->query( 'SELECT * FROM ads WHERE id = ? ',
        $ad_id )->hash;

    return $self->render(
        json   => { success => 0, error => 'Ad not found or not authorized' },
        status => 404
    ) unless $ad;

    my $result = $self->pg->db->query( 'DELETE FROM ads WHERE id = ?', $ad_id );

    if ( $result->rows == 0 ) {
        return $self->render(
            json   => { success => 0, error => 'Failed to delete ad' },
            status => 500
        );
    }

    $self->render(
        json => {
            success => 1,
            message => "Ad deleted successfully"
        }
    );
}



sub searchAd ($self) {

  my $query = $self->param('query');

  return $self->render(
    json => {
        success=>1,
        message => 'No search query provided',
        ads => [],
    }
  ) unless $query;

  my $ads = $self->pg->db->query('SELECT * FROM ads WHERE title ILIKE ? ORDER BY created_at desc',
  '%'. $query . '%'
  )->hashes->to_array;

  $self->render(
    json => {
        success => 1,
        message => 'Search completed',
        ads => $ads,
    }
  );


};



sub updateStatus ($self) {
    my $user_id = $self->current_user_id;
    return $self->render( json => { error => 'Unauthorized'}, status => 401)
      unless $user_id;

    my $ad_id = $self->stash('id');

    my $ad = $self->pg->db->query('SELECT * from ads WHERE id=? AND user_id=?',
      $ad_id, $user_id)->hash;

    return $self->render( 
      json => { error => 'Ad not found or not authorized'}, 
      status => 400
    ) unless $ad;

    $self->pg->db->query('UPDATE ads SET status=? WHERE id=?', 0, $ad_id);

    $self->render(
        json => {
          success => 1,
          message => 'Ad status update successfully',
          ad => {
            id       => $ad_id,
            user_id  => $user_id,
            status   => 0,
          }
        }
    );
};



1;

