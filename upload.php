<?php

if (isset($_FILES['image'])) {
    $errors = array();
    $file_name = $_FILES['image']['name'];
    $file_size = $_FILES['image']['size'];
    $file_tmp = $_FILES['image']['tmp_name'];
    $file_type = $_FILES['image']['type'];
    $file_ext = strtolower(end(explode('.', $_FILES['image']['name'])));
    if ($file_size > 1048576) {
        $errors[] = 'File size must be less than 1MB';
    }
    if (empty($errors) == true) {
        move_uploaded_file($file_tmp, "images/" . $file_name);
        echo json_encode(array('msg'=>"Successfully Uploaded.","filename" => $file_name));

    } else {
       // print_r($errors);  // not necessary because we are not checking for the server response in the front end.
        echo json_encode(array('msg'=>"Please Try again."));
    }
}