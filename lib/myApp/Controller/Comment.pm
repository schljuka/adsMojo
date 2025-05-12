package myApp::Controller::Comment;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Scalar::Util qw(looks_like_number);

sub createComment ($self) {
    my $user_id = $self->current_user_id;
    return $self->render( json => { error => 'Unauthorized' }, status => 401 )
      unless $user_id;

    my $ad_id   = $self->stash('id');
    my $content = $self->param('content');
    my $rating  = $self->param('rating');

    return $self->render(
        json   => { success => 0, error => 'Missing data' },
        status => 400
    ) unless ( $ad_id && $content && $rating );

    unless ( looks_like_number($rating) && $rating >= 0 && $rating <= 5 ) {
        return $self->render(
            json => {
                success => 0,
                error   => 'Rating must be a number between 0 and 5'
            },
            status => 400,
        );
    }

    $self->pg->db->query(
'INSERT INTO comments (ad_id, user_id, content, rating) VALUES (?, ?, ?, ?)',
        $ad_id, $user_id, $content, $rating );

    $self->render(
        json => {
            success => 1,
            message => 'Comment created successfuly',
            comment => {
                user_id => $user_id,
                content => $content,
                rating  => $rating,
            }
        }
    );

}

sub editComment ($self) {
    my $user_id = $self->current_user_id;
    return $self->render( json => { error => 'Unauthorized' }, status => 401 )
      unless $user_id;

    my $comment_id = $self->stash('id');
    my $content    = $self->param('content');

    return $self->render(
        json   => { success => 0, error => 'Missing data' },
        status => 400
    ) unless $comment_id && $content;

    my $comment =
      $self->pg->db->query( 'SELECT * from comments WHERE id=? AND user_id=?',
        $comment_id, $user_id )->hash;

    return $self->render(
        json =>
          { success => 0, error => 'Comment not found or not authorized' },
        status => 400
    ) unless $comment;

    $self->pg->db->query( 'UPDATE comments SET content=? WHERE id=?',
        $content, $comment_id );

    $self->render(
        json => {
            success => 1,
            message => 'Comment update successfuly',
            comment => {
                id      => $comment_id,
                user_id => $user_id,
                content => $content,
            }
        }
    );
}

sub getAllComments ($self) {

    my $comments =
      $self->pg->db->query('SELECT * from comments order by created_at desc')
      ->hashes->to_array;

    $self->render(
        json => {
            success  => 1,
            message  => 'Gett all comments successfuly',
            comments => $comments,
        }
    );
}

sub deleteComment ($self) {

    my $user_id = $self->current_user_id;
    return $self->render( json => { error => 'Unauthorized' }, status => 401 )
      unless $user_id;

    my $comment_id = $self->stash('id');

    return $self->render(
        json   => { error => 'Comment id is required' },
        status => 400,
    ) unless $comment_id;

    my $comment =
      $self->pg->db->query( 'SELECT * from comments WHERE id=? AND user_id=?',
        $comment_id, $user_id )->hash;

    return $self->render(
        json   => { error => 'Comment not found or not authorized' },
        status => 400
    ) unless $comment;

    my $result =
      $self->pg->db->query( 'DELETE FROM comments WHERE id=?', $comment_id );

    if ( $result->rows == 0 ) {
        return $self->render(
            json   => { success => 0, error => 'Failed to delete comment' },
            status => 500,
        );
    }

    $self->render(
        json => {
            status  => 1,
            message => 'Commend deleted successfuly',
        }

    );

}

1;
