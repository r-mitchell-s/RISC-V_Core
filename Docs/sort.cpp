void bubbleSort(vector<int>& vec) {

    // print the unsorted vector
    printf("Unsorted bubble_vec: %d\n", bubble_vec);

    // iterate through each element in the list
    for (int i = 0; i < vec.size(); i++) {
        for (int j = ) {
            if (vec[i] > vec[i + 1]) {
                int temp = vec[i];
                vec[i] = vec[i+1];
                vec[i+1] = temp;
            }
        }
    }

    // print the sorted vector
    printf("Sorted bubble_vec: %d\n", bubble_vec);
}

void insertionSort(vector<int>& vec) {

    // print the unsorted vector
    printf("Unsorted selection_vec: %d\n", insert_vec); 
       

    // iterate through the list

    // print the sorted vector
    printf("Sorted selection_vec: %d\n", insert_vec);
    
}

void selectionSort(vector<int>& vec) {

    // print the unsorted vector
    printf("Unsorted merge_vec: %d\n", selection_vec); 
       
    // print the sorted vector
    printf("Sorted merge_vec: %d\n", selection_vec);
    
}

void mergeSort(vector<int>& vec) {

    // print the unsorted vector
    printf("Unsorted quick_vec: %d\n", merge_vec); 
       
    // print the sorted vector
    printf("Sorted quick_vec: %d\n", merge_vec);
    
}

void quickSort(vector<int>& vec) {

    // print the unsorted vector
    printf("Unsorted insert_vec: %d\n", quick_vec); 
       
    // print the sorted vector
    printf("Sorted insert_vec: %d\n", quick_vec);
    
}

// main
void main() {

    std::vector<int> bubble_vec = {1, 4, 2, 5, 3};
    std::vector<int> insert_vec = {1, 4, 2, 5, 3};
    std::vector<int> selection_vec = {1, 4, 2, 5, 3};
    std::vector<int> merge_vec = {1, 4, 2, 5, 3};
    std::vector<int> quick_vec = {1, 4, 2, 5, 3};

    bubbleSort(bubble_vec);
    insertionSort(insertion_vec);
    selectionSort(selection_vec);
    mergeSort(merge_vec);
    quickSort(quick_vec);
}