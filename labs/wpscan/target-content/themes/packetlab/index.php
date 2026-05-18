<?php get_header(); ?>

<main>
  <h1><?php bloginfo('name'); ?></h1>
  <p><?php bloginfo('description'); ?></p>

  <?php if (have_posts()) : ?>
    <?php while (have_posts()) : the_post(); ?>
      <article>
        <h2><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2>
        <?php the_excerpt(); ?>
      </article>
    <?php endwhile; ?>
  <?php else : ?>
    <p>No posts yet.</p>
  <?php endif; ?>
</main>

<?php get_footer(); ?>
